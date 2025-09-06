package thresholdcore

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strconv"
	"testing"

	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
	"github.com/stretchr/testify/assert"
)

type Root struct {
	Config Config `json:"config"`
	Inputs Inputs `json:"inputs"`
}

type Config struct {
	MaxParticipants uint16 `json:"MAX_PARTICIPANTS"`
	MinParticipants uint16 `json:"MIN_PARTICIPANTS"`
	Name            string `json:"name"`
	Group           string `json:"group"`
	Hash            string `json:"hash"`
}

type Scalar secp.ModNScalar

type Participant struct {
	Identifier       Identifier                        `json:"identifier"`
	SecretKey        SecretKey                         `json:"secret_key"`
	Coefficient      Scalar                            `json:"coefficient"`
	VSSCommitments   VerifiableSecretSharingCommitment `json:"vss_commitments"`
	ProofOfKnowledge Scalar                            `json:"proof_of_knowledge"`
	SecretShares     map[int]SecretShare               `json:"secret_shares"` // keys "1","2","3" → ints
	VerifyingShare   VerifyingShare                    `json:"verifying_share"`
	SecretShare      SecretShare                       `json:"secret_share"`
}

type Inputs struct {
	VerifyingKey VerifyingKey        `json:"verifying_key"`
	Participants map[int]Participant `json:"-"`
}

func (scalar *Scalar) UnmarshalJSON(b []byte) error {
	var hexStr string
	if err := json.Unmarshal(b, &hexStr); err != nil {
		return err
	}
	raw, err := hex.DecodeString(hexStr)
	if err != nil {
		return fmt.Errorf("scalar hex: %w", err)
	}
	var tmp secp.ModNScalar
	_ = tmp.SetByteSlice(raw)

	*scalar = Scalar(tmp)
	return nil
}

// ====== Inputs custom unmarshal (handles numeric keys) ======

func (in *Inputs) UnmarshalJSON(b []byte) error {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(b, &raw); err != nil {
		return err
	}
	in.Participants = make(map[int]Participant)
	for k, v := range raw {
		if k == "verifying_key" {
			if err := json.Unmarshal(v, &in.VerifyingKey); err != nil {
				return fmt.Errorf("verifying_key: %w", err)
			}
			continue
		}
		// numeric participant key?
		if id, err := strconv.Atoi(k); err == nil {
			var p Participant
			if err := json.Unmarshal(v, &p); err != nil {
				return fmt.Errorf("participant %s: %w", k, err)
			}
			in.Participants[id] = p
		}
		// silently ignore any other fields
	}
	return nil
}

// small helper to avoid importing bytes just for NewReader in tiny samples
type reader struct {
	b []byte
	i int
}

func LoadRootFromFile(path string) (*Root, error) {
	var r Root
	f, err := os.Open(path) // just to get a ReadCloser for defer
	if err != nil {
		panic(err)
	}
	defer f.Close()

	dec := json.NewDecoder(f)
	dec.DisallowUnknownFields() // optional: catch unexpected fields
	if err := dec.Decode(&r); err != nil {
		return nil, fmt.Errorf("unmarshal: %w", err)
	}
	return &r, nil
}

func TestDealerDkg(t *testing.T) {
	// Example from spec doc
	const jsonPath = "vectors_dkg.json"
	root, err := LoadRootFromFile(jsonPath)
	if err != nil {
		t.Fatalf("load root: %v", err)
	}
	config := root.Config
	inputs := root.Inputs

	keypackage, pubkey_package, err := DealerDKG(config, inputs)

	assert.NoError(t, err, "DealerDKG")

	minParticipants := uint16(config.MinParticipants)
	_ = uint16(config.MaxParticipants)

	paticipantsShares := make(map[Identifier]SecretShare)
	for _, p := range inputs.Participants {
		paticipantsShares[p.Identifier] = p.SecretShare
	}

	reconstructed_key, err := Reconstruct(minParticipants, paticipantsShares)

	assert.NoError(t, err, "Reconstruct")

	calculated_keys := secp.ModNScalar{}

	for _, p := range keypackage {
		secret_key := se

	}

}

// DealerDKG is a quick path that runs a complete (non-interactive) flow
// for N participants locally (useful for tests).
func DealerDKG(config Config, inputs Inputs) ([]KeyPackage, PublicKeyPackage, error) {
	minParticipants := config.MinParticipants
	maxParticipants := config.MaxParticipants

	if err := validateNumOfSigners(minParticipants, maxParticipants); err != nil {
		return nil, PublicKeyPackage{}, err
	}

	ids := make([]Identifier, 0, maxParticipants)
	for _, participant := range inputs.Participants {
		ids = append(ids, participant.Identifier)
	}
	if len(ids) != int(maxParticipants) {
		return nil, PublicKeyPackage{}, ErrIncorrectNumberOfIds
	}

	// Everyone runs part1
	r1Secrets := make(map[Identifier]Round1SecretPackage, maxParticipants)
	r1Pkgs := make(map[Identifier]Round1Package, minParticipants)

	for _, participant := range inputs.Participants {

		coefficients := []secp.ModNScalar{secp.ModNScalar(participant.Coefficient)}
		sec, pkg, err := DKGPart1(participant.Identifier, maxParticipants, minParticipants, participant.SecretKey, coefficients, rand.Reader)
		if err != nil {
			return nil, PublicKeyPackage{}, err
		}
		r1Secrets[participant.Identifier] = sec
		r1Pkgs[participant.Identifier] = pkg
	}
	// Everyone runs part2
	r2Secrets := make(map[Identifier]Round2SecretPackage, maxParticipants)
	r2Outgoing := make(map[Identifier]map[Identifier]Round2Package, maxParticipants)
	for _, id := range ids {
		// Build "others'" map for this participant
		others := make(map[Identifier]Round1Package, int(maxParticipants-1))
		for _, j := range ids {
			if j.Equal(id) {
				continue
			}
			others[j] = r1Pkgs[j]
		}
		r2s, out, err := DKGPart2(r1Secrets[id], others)
		if err != nil {
			return nil, PublicKeyPackage{}, err
		}
		r2Secrets[id] = r2s
		r2Outgoing[id] = out
	}

	// Deliver round2 messages and run part3
	keys := make([]KeyPackage, 0, maxParticipants)
	var pkp PublicKeyPackage

	for _, id := range ids {
		// Build inbound map for this participant
		r2View := make(map[Identifier]Round2Package, int(maxParticipants-1))
		r1view := make(map[Identifier]Round1Package, int(maxParticipants-1))
		for _, j := range ids {
			if j.Equal(id) {
				continue
			}
			r2View[j] = r2Outgoing[j][id]
			r1view[j] = r1Pkgs[j]
		}

		pRound1Secret := r1Secrets[id]
		pRound2Secret := r2Secrets[id]
		kp, pk, err := DKGPart3(&pRound1Secret, &pRound2Secret, r1view, r2View)
		if err != nil {
			return nil, PublicKeyPackage{}, err
		}
		keys = append(keys, kp)
		if len(pkp.VerifyingShares) == 0 {
			pkp = pk
		}
	}

	// Deterministic order
	sort.Slice(keys, func(i, j int) bool {
		return keys[i].Identifier.Less(keys[j].Identifier)
	})
	return keys, pkp, nil
}
