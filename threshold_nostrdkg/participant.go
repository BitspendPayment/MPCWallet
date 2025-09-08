package thresholdnostrdkg

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"sync"
	"sync/atomic"

	thres "github.com/ArkLabsHQ/thresholdmagic/thresholdcore"
	"github.com/decred/dcrd/dcrec/secp256k1/v4"
	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
	"github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
)

type DKGParticipant struct {
	nostrPackage     NostrPackage
	thresholdPackage ThresholdPackage
	min              uint16
	max              uint16
	temp             TempPackage
}

type NostrPackage struct {
	secretKey          string
	PublicKey          string
	relayUrl           string
	relay              *nostr.Relay
	participantPubkeys []string
}

type ThresholdPackage struct {
	KeyPackage    *thres.KeyPackage
	secrectKey    secp256k1.ModNScalar
	pubkeyPackage *thres.PublicKeyPackage
}

type TempPackage struct {
	Identifier      *thres.Identifier
	Round1Secret    *thres.Round1SecretPackage
	Round1Pub       *thres.Round1Package
	Ruund2Secret    *thres.Round2SecretPackage
	Round2Pub       map[thres.Identifier]thres.Round2Package
	Round1PubMap    sync.Map
	Round1PubMapLen atomic.Uint32
	Round2PubMapLen atomic.Uint32
	round1Lock      sync.RWMutex
	round2Lock      sync.RWMutex
}

func NewDKGParticipant(secretKey []byte, relayUrl string, min, max uint16) (DKGParticipant, error) {
	secretKeyHex := hex.EncodeToString(secretKey)
	nostrPublicKey, err := nostr.GetPublicKey(secretKeyHex)

	if err != nil {
		return DKGParticipant{}, err
	}

	nostrRelay, err := nostr.RelayConnect(context.Background(), relayUrl)
	if err != nil {
		return DKGParticipant{}, err
	}

	var thresholdSecret secp256k1.ModNScalar
	thresholdSecret.SetByteSlice(secretKey)

	return DKGParticipant{
		nostrPackage: NostrPackage{
			secretKey: secretKeyHex,
			PublicKey: nostrPublicKey,
			relayUrl:  relayUrl,
			relay:     nostrRelay,
		},
		thresholdPackage: ThresholdPackage{
			secrectKey: thresholdSecret,
		},
		min: min,
		max: max,
	}, nil
}

func (p *DKGParticipant) AddDKGParticipant(nostrPubKey string) error {
	if p.max == uint16(len(p.nostrPackage.participantPubkeys)) {
		return ErrMaxParticipantsReached
	}

	p.nostrPackage.participantPubkeys = append(p.nostrPackage.participantPubkeys, nostrPubKey)

	return nil
}

func (p *DKGParticipant) IniatiateNostrDKG() error {
	// Start DKG process
	tags := nostr.Tags{}

	for _, pk := range p.nostrPackage.participantPubkeys {
		tags = append(tags, nostr.Tag{"p", pk})
	}

	tags = append(tags, nostr.Tag{"dkg", "initiate"})

	event := nostr.Event{
		PubKey:  p.nostrPackage.PublicKey,
		Content: "Initiating DKG",
		Kind:    nostr.KindTextNote,
		Tags:    tags,
	}

	if err := event.Sign(p.nostrPackage.secretKey); err != nil {
		return err
	}

	err := p.nostrPackage.relay.Publish(context.Background(), event)

	if err != nil {
		go p.handleIncomingDKGMessages(context.Background())
	}
	return err
}

func (p *DKGParticipant) handleIncomingDKGMessages(ctx context.Context) {
	// Subscribe to DKG events
	filters := nostr.Filters{
		{
			Kinds:   []int{nostr.KindTextNote},
			Authors: append(p.nostrPackage.participantPubkeys, p.nostrPackage.PublicKey),
			Tags:    nostr.TagMap{"dkg": []string{"initiate", "round1", "round2", "complete"}, "p": []string{p.nostrPackage.PublicKey}},
		},
	}

	sub, err := p.nostrPackage.relay.Subscribe(ctx, filters)
	if err != nil {
		// handle error
		panic(err)
	}

	for event := range sub.Events {
		// Process each incoming DKG message
		if event.Tags.ContainsAny("dkg", []string{"round1"}) {
			var round1Pub thres.Round1Package
			err := json.Unmarshal([]byte(event.Content), &round1Pub)
			if err != nil {
				// handle error
				continue
			}

			author := event.PubKey
			authorBytes, err := hex.DecodeString(author)

			var id secp.ModNScalar
			id.SetByteSlice(authorBytes)

			identifier := thres.Identifier{S: id}

			p.temp.Round1PubMap.Store(identifier, round1Pub)

			partipcipantsLen := p.temp.Round1PubMapLen.Add(1)

			if p.max == uint16(partipcipantsLen) {
				// All round 1 messages received, proceed to distribute shares
				p.distributeDKGShares()
			}

		} else if event.Tags.ContainsAny("dkg", []string{"round2"}) && event.Tags.ContainsAny("p", []string{p.nostrPackage.PublicKey}) {
			// Decrypt and process round 2 message
			conversationKey, err := nip44.GenerateConversationKey(event.PubKey, p.nostrPackage.secretKey)
			if err != nil {
				println("Error generating conversation key:", err)
				continue
			}

			decrypted, err := nip44.Decrypt(event.Content, conversationKey)

			if err != nil {
				println("Error decrypting message:", err)
				continue
			}

			var round2Pub thres.Round2Package
			err = json.Unmarshal([]byte(decrypted), &round2Pub)
			if err != nil {
				// handle error
				continue
			}

			author := event.PubKey
			authorBytes, err := hex.DecodeString(author)

			var id secp.ModNScalar
			id.SetByteSlice(authorBytes)

			identifier := thres.Identifier{S: id}

			p.temp.round2Lock.Lock()

			if p.temp.Round2Pub == nil {
				p.temp.Round2Pub = make(map[thres.Identifier]thres.Round2Package)
			}
			p.temp.Round2Pub[identifier] = round2Pub

			partipcipantsLen := p.temp.Round2PubMapLen.Add(1)

			p.temp.round2Lock.Unlock()

			if p.max == uint16(partipcipantsLen) {
				// All round 2 messages received, proceed to complete DKG
				p.completeDKG()
			}

		}
	}

}

func (p *DKGParticipant) StartDKGSession(relay *nostr.Relay) error {

	pubkeyBytes, err := hex.DecodeString(p.nostrPackage.PublicKey)
	if err != nil {
		return err
	}

	var s secp.ModNScalar
	s.SetByteSlice(pubkeyBytes)

	identifier := thres.Identifier{S: s}
	coefficients, err := thres.GenerateCoefficients(p.min)

	if err != nil {
		return err
	}

	thresSecretKey := thres.SecretKey{Scalar: p.thresholdPackage.secrectKey}

	round1Secret, round1Pub, err := thres.DKGPart1(identifier, p.max, p.min, thresSecretKey, coefficients, rand.Reader)

	p.temp.round1Lock.Lock()
	defer p.temp.round1Lock.Unlock()

	p.temp.Round1Secret = &round1Secret
	p.temp.Round1Pub = &round1Pub
	p.temp.Identifier = &identifier

	serialisedRound1Pub, err := json.Marshal(round1Pub)
	if err != nil {
		return err
	}

	event := nostr.Event{
		PubKey:  p.nostrPackage.PublicKey,
		Content: string(serialisedRound1Pub),
		Kind:    nostr.KindTextNote,
		Tags:    nostr.Tags{{"dkg", "round1"}},
	}

	if err := event.Sign(p.nostrPackage.secretKey); err != nil {
		return err
	}

	err = relay.Publish(context.Background(), event)

	if err != nil {
		return err
	}

	return nil
}

func (p *DKGParticipant) distributeDKGShares() error {
	p.temp.round1Lock.RLock()
	defer p.temp.round1Lock.RUnlock()

	secretPackage := p.temp.Round1Secret
	publicPackage := make(map[thres.Identifier]thres.Round1Package)

	p.temp.Round1PubMap.Range(func(key, value any) bool {
		id, ok1 := key.(thres.Identifier)
		round1Pub, ok2 := value.(thres.Round1Package)
		if ok1 && ok2 {
			publicPackage[id] = round1Pub
		}
		return true
	})

	round2SecretPackage, round2PublicPackage, err := thres.DKGPart2(*secretPackage, publicPackage)

	if err != nil {
		return err
	}

	p.temp.round2Lock.Lock()
	defer p.temp.round2Lock.Unlock()

	p.temp.Ruund2Secret = &round2SecretPackage
	p.temp.Round2Pub = round2PublicPackage

	for id, pkg := range round2PublicPackage {
		serialisedRound2Pub, err := json.Marshal(pkg)
		if err != nil {
			return err
		}

		idSlice := id.S.Bytes()
		receipient := hex.EncodeToString(idSlice[:])

		conversationKey, err := nip44.GenerateConversationKey(receipient, p.nostrPackage.secretKey)

		encrypted, err := nip44.Encrypt(string(serialisedRound2Pub), conversationKey)
		if err != nil {
			return err
		}

		event := nostr.Event{
			PubKey:  p.nostrPackage.PublicKey,
			Content: encrypted,
			Kind:    nostr.KindEncryptedDirectMessage,
			Tags:    nostr.Tags{{"dkg", "round2", "p", receipient}},
		}

		if err := event.Sign(p.nostrPackage.secretKey); err != nil {
			return err
		}

		err = p.nostrPackage.relay.Publish(context.Background(), event)

		if err != nil {
			return err
		}
	}

	return nil

}

func (p *DKGParticipant) completeDKG() error {
	p.temp.round1Lock.RLock()
	defer p.temp.round1Lock.RUnlock()

	p.temp.round2Lock.RLock()
	defer p.temp.round2Lock.RUnlock()

	round1Secret := p.temp.Round1Secret
	round2Secret := p.temp.Ruund2Secret

	round2Pub := p.temp.Round2Pub

	round1PubMap := make(map[thres.Identifier]thres.Round1Package)

	p.temp.Round1PubMap.Range(func(key, value any) bool {
		id, ok1 := key.(thres.Identifier)
		round1Pub, ok2 := value.(thres.Round1Package)
		if ok1 && ok2 {
			round1PubMap[id] = round1Pub
		}
		return true
	})

	keyPackage, pubkeyPackage, err := thres.DKGPart3(round1Secret, round2Secret, round1PubMap, round2Pub)
	if err != nil {
		return err
	}

	p.thresholdPackage.KeyPackage = &keyPackage
	p.thresholdPackage.pubkeyPackage = &pubkeyPackage

	// Announce completion
	serialisedPubkeyPackage, err := json.Marshal(pubkeyPackage)
	if err != nil {
		return err
	}

	event := nostr.Event{
		PubKey:  p.nostrPackage.PublicKey,
		Content: string(serialisedPubkeyPackage),
		Kind:    nostr.KindTextNote,
		Tags:    nostr.Tags{{"dkg", "complete"}},
	}

	if err := event.Sign(p.nostrPackage.secretKey); err != nil {
		return err
	}

	err = p.nostrPackage.relay.Publish(context.Background(), event)

	return err

}

func ReceiveDKGMessages(ctx context.Context, relay *nostr.Relay, handler func(msg string)) {
	// Subscribe to DKG events and call handler(msg) for each
	// ...
}

// Random non-zero scalar
func modNRandom() (secp.ModNScalar, error) {
	for {
		var b [32]byte
		if _, err := rand.Read(b[:]); err != nil {
			return secp.ModNScalar{}, err
		}
		var s secp.ModNScalar
		_ = s.SetByteSlice(b[:])
		if !s.IsZero() {
			return s, nil
		}
	}
}
