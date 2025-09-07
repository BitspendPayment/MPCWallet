package thresholdcore

import (
	"crypto/rand"
	"sort"
	"testing"

	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
	"github.com/stretchr/testify/assert"
)

type Participant struct {
	Identifier   Identifier
	SecretKey    SecretKey
	Coefficients []secp.ModNScalar
}

func TestDealerDkg(t *testing.T) {

	minParticipants := uint16(2)
	maxParticipants := uint16(3)

	ids, err := defaultIdentifiers(maxParticipants)
	assert.NoError(t, err, "defaultIdentifiers")

	participants := make([]Participant, 0, maxParticipants)
	for i := 0; i < int(maxParticipants); i++ {
		secret, err := modNRandom()
		coefficients, err := generateCoefficients(int(minParticipants) - 1)
		assert.NoError(t, err, "NewSecretKey")

		participants = append(participants, Participant{
			Identifier:   ids[i],
			SecretKey:    SecretKey{secret},
			Coefficients: coefficients,
		})

	}
	keypackage, _, err := DealerDKG(minParticipants, maxParticipants, participants)

	assert.NoError(t, err, "DealerDKG")

	paticipantsShares := make(map[Identifier]SecretShare, maxParticipants)
	for _, p := range keypackage {
		paticipantsShares[p.Identifier] = p.SecretShare
	}

	reconstructed_key, err := Reconstruct(minParticipants, paticipantsShares)

	assert.NoError(t, err, "Reconstruct")

	var calculated_keys secp.ModNScalar

	for _, p := range participants {
		calculated_keys.Add(&p.SecretKey.Scalar)
	}

	isEqual := reconstructed_key.Scalar.Equals(&calculated_keys)

	assert.True(t, isEqual, "Reconstructed key matches sum of shares")

}

// DealerDKG is a quick path that runs a complete (non-interactive) flow
// for N participants locally (useful for tests).
func DealerDKG(min uint16, max uint16, participants []Participant) ([]KeyPackage, PublicKeyPackage, error) {

	if err := validateNumOfSigners(min, max); err != nil {
		return nil, PublicKeyPackage{}, err
	}

	ids := make([]Identifier, 0, max)
	for _, participant := range participants {
		ids = append(ids, participant.Identifier)
	}
	if len(ids) != int(max) {
		return nil, PublicKeyPackage{}, ErrIncorrectNumberOfIds
	}

	// Everyone runs part1
	r1Secrets := make(map[Identifier]Round1SecretPackage, max)
	r1Pkgs := make(map[Identifier]Round1Package, min)

	for _, participant := range participants {

		sec, pkg, err := DKGPart1(participant.Identifier, max, min, participant.SecretKey, participant.Coefficients, rand.Reader)
		if err != nil {
			return nil, PublicKeyPackage{}, err
		}
		r1Secrets[participant.Identifier] = sec
		r1Pkgs[participant.Identifier] = pkg
	}
	// Everyone runs part2
	r2Secrets := make(map[Identifier]Round2SecretPackage, max)
	r2Outgoing := make(map[Identifier]map[Identifier]Round2Package, max)
	for _, id := range ids {
		// Build "others'" map for this participant
		others := make(map[Identifier]Round1Package, int(max-1))
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
	keys := make([]KeyPackage, 0, max)
	var pkp PublicKeyPackage

	for _, id := range ids {
		// Build inbound map for this participant
		r2View := make(map[Identifier]Round2Package, int(max-1))
		r1view := make(map[Identifier]Round1Package, int(max-1))
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
