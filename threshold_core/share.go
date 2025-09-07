package thresholdcore

import (
	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
)

// SecretShare delivered by dealer
type ThresholdShare struct {
	Identifier Identifier
	SecretSh   SecretShare
	VeriyingSh VerifyingShare
	Commitment VerifiableSecretSharingCommitment
}

type SecretShare secp.ModNScalar

type VerifyingShare = secp.JacobianPoint

type VerifyingKey struct {
	E secp.JacobianPoint
}

// Verify share against VSS; returns (verifying_share_i, group_verifying_key)
func (s ThresholdShare) Verify() (VerifyingShare, VerifyingKey, error) {
	left := elemBaseMul((*secp.ModNScalar)(&s.SecretSh)) // g * f(i)
	right := s.Commitment.GetVerifyingShare(s.Identifier)

	equal := left.EquivalentNonConst(&right)

	if !equal {
		return VerifyingShare{}, VerifyingKey{}, ErrInvalidSecretShare
	}
	groupVK, err := s.Commitment.ToVerifyingKey()
	if err != nil {
		return VerifyingShare{}, VerifyingKey{}, err
	}
	return right, groupVK, nil
}

// Reconstruct original SigningKey from >= t KeyPackages
func Reconstruct(minParticipants uint16, participants map[Identifier]SecretShare) (SecretKey, error) {
	if len(participants) == 0 {
		return SecretKey{}, ErrIncorrectNumberOfShares
	}

	if len(participants) < int(minParticipants) {
		return SecretKey{}, ErrIncorrectNumberOfShares
	}

	ids := make([]Identifier, 0, len(participants))
	for id := range participants {
		ids = append(ids, id)
	}

	var secret secp.ModNScalar // zero scalar by default

	for i, k := range participants {
		l := lagrangeCoeffAtZero(i, ids)      // returns ModNScalar
		part := l.Mul((*secp.ModNScalar)(&k)) // convert SecretShare to *secp.ModNScalar
		secret.Add(part)                      // secret += part
	}

	return SecretKey{Scalar: secret}, nil
}
