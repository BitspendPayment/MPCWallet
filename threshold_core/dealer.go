package thresholdcore

import (
	"io"

	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
)

type IdentifierList int

const (
	IdentifiersDefault IdentifierList = iota
)

type SecretKey struct {
	Scalar secp.ModNScalar
}

func GenerateWithDealer(maxSigners, minSigners uint16) (map[Identifier]SecretShare, VerifyingKey, error) {
	key, err := modNRandom()
	if err != nil {
		return nil, VerifyingKey{}, err
	}
	return Split(key, maxSigners, minSigners)
}

// Generate polynomial (+commitments) with secret as c0
func generateSecretPolynomial(
	secret *secp.ModNScalar,
	maxSigners, minSigners uint16,
	coeffOnly []secp.ModNScalar,
) ([]secp.ModNScalar, VerifiableSecretSharingCommitment, error) {

	if err := validateNumOfSigners(minSigners, maxSigners); err != nil {
		return nil, VerifiableSecretSharingCommitment{}, err
	}
	if len(coeffOnly) != int(minSigners)-1 {
		return nil, VerifiableSecretSharingCommitment{}, ErrInvalidCoefficients
	}

	coeffs := make([]secp.ModNScalar, 0, len(coeffOnly)+1)
	coeffs = append(coeffs, *secret) // c0 = secret
	coeffs = append(coeffs, coeffOnly...)

	commit := make([]CoefficientCommitment, len(coeffs))
	for i := range coeffs {
		commit[i] = newCoefficientCommitment(elemBaseMul(&coeffs[i]))
	}
	return coeffs, newVSSCommitment(commit), nil
}

func generateSecretShares(
	secret *secp.ModNScalar,
	maxSigners, minSigners uint16,
	coeffOnly []secp.ModNScalar,
	ids []Identifier,
) ([]ThresholdShare, VerifiableSecretSharingCommitment, error) {

	coeffs, commit, err := generateSecretPolynomial(secret, maxSigners, minSigners, coeffOnly)
	if err != nil {
		return nil, VerifiableSecretSharingCommitment{}, err
	}

	// ensure unique ids
	set := make(map[string]struct{}, len(ids))
	for _, id := range ids {
		k := string(id.Serialize())
		if _, ok := set[k]; ok {
			return nil, VerifiableSecretSharingCommitment{}, ErrDuplicatedIdentifier
		}
		set[k] = struct{}{}
	}

	out := make([]ThresholdShare, 0, len(ids))
	for _, id := range ids {
		si := evaluatePolynomial(id, coeffs)
		ss := newSigningShare(si)
		out = append(out, NewThresholdShare(id, ss, commit))
	}
	return out, commit, nil
}

func generateCoefficients(size int) ([]secp.ModNScalar, error) {
	out := make([]secp.ModNScalar, size)
	for i := 0; i < size; i++ {
		s, err := modNRandom()
		if err != nil {
			return nil, err
		}
		out[i] = s
	}
	return out, nil
}

func validateNumOfSigners(minSigners, maxSigners uint16) error {
	if minSigners < 2 {
		return ErrInvalidMinSigners
	}
	if maxSigners < 2 {
		return ErrInvalidMaxSigners
	}
	if minSigners > maxSigners {
		return ErrInvalidMinSigners
	}
	return nil
}

func NewSecretKey(r io.Reader) (*SecretKey, error) {
	var s secp.ModNScalar
	for {
		var b [32]byte
		if _, err := r.Read(b[:]); err != nil {
			return nil, err
		}
		_ = s.SetByteSlice(b[:])
		if !s.IsZero() {
			break
		}
	}
	return &SecretKey{Scalar: s}, nil
}

func Split(
	key secp.ModNScalar,
	maxSigners, minSigners uint16,
) (map[Identifier]SecretShare, VerifyingKey, error) {

	if err := validateNumOfSigners(minSigners, maxSigners); err != nil {
		return nil, VerifyingKey{}, err
	}
	var err error

	ids, err := defaultIdentifiers(maxSigners)
	if err != nil {
		return nil, VerifyingKey{}, err
	}

	coeffs, err := generateCoefficients(int(minSigners) - 1)
	if err != nil {
		return nil, VerifyingKey{}, err
	}

	shares, commit, err := generateSecretShares(&key, maxSigners, minSigners, coeffs, ids)
	if err != nil {
		return nil, VerifyingKey{}, err
	}

	verifyingShares := make(map[Identifier]VerifyingShare, len(shares))
	byID := make(map[Identifier]SecretShare, len(shares))
	for _, s := range shares {
		verifyingShares[s.Identifier] = verifyingShareFromSigning(s)
		byID[s.Identifier] = s.SecretSh
	}

	vk, err := VerifyingKeyFromCommitment(commit)
	if err != nil {
		return nil, VerifyingKey{}, err
	}
	return byID, vk, nil
}

func defaultIdentifiers(maxSigners uint16) ([]Identifier, error) {
	out := make([]Identifier, 0, maxSigners)
	for i := uint16(1); i <= maxSigners; i++ {
		id, err := FromUint16(i)
		if err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, nil
}
