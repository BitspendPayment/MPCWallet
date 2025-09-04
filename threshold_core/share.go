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

func NewThresholdShare(id Identifier, ss SecretShare, com VerifiableSecretSharingCommitment) ThresholdShare {
	return ThresholdShare{
		Identifier: id,
		SecretSh:   ss,
		Commitment: com,
	}
}

type SecretShare struct {
	s secp.ModNScalar
}

func newSigningShare(s secp.ModNScalar) SecretShare {
	return SecretShare{s: s}
}
func (ss SecretShare) ToScalar() secp.ModNScalar { return ss.s }
func (ss SecretShare) Serialize() []byte         { be := ss.s.Bytes(); return be[:] }

type VerifyingShare struct {
	E secp.JacobianPoint
}

func newVerifyingShare(e secp.JacobianPoint) VerifyingShare { return VerifyingShare{E: e} }
func (vs VerifyingShare) Serialize() ([]byte, error) {
	return elemSerializeCompressed(vs.E)
}

func verifyingShareFromSigning(ss ThresholdShare) VerifyingShare {
	e := elemBaseMul(&ss.SecretSh.s)
	return newVerifyingShare(e)
}

type VerifyingKey struct {
	E secp.JacobianPoint
}

func VerifyingKeyFromCommitment(vss VerifiableSecretSharingCommitment) (VerifyingKey, error) {
	if len(vss.Coeffs) == 0 {
		return VerifyingKey{}, ErrInvalidCommitVector
	}
	return VerifyingKey{E: vss.Coeffs[0].E}, nil
}

// Verify share against VSS; returns (verifying_share_i, group_verifying_key)
func (s ThresholdShare) Verify() (VerifyingShare, VerifyingKey, error) {
	left := elemBaseMul(&s.SecretSh.s) // g * f(i)
	right := evaluateVSS(s.Identifier, &s.Commitment)
	// compare compressed encodings
	lb, _ := elemSerializeCompressed(left)
	rb, _ := elemSerializeCompressed(right)
	equal := len(lb) == len(rb)
	if equal {
		for i := range lb {
			if lb[i] != rb[i] {
				equal = false
				break
			}
		}
	}
	if !equal {
		return VerifyingShare{}, VerifyingKey{}, ErrInvalidSecretShare
	}
	groupVK, err := VerifyingKeyFromCommitment(s.Commitment)
	if err != nil {
		return VerifyingShare{}, VerifyingKey{}, err
	}
	return newVerifyingShare(right), groupVK, nil
}

// ===========================================================
// Lagrange reconstruction at x=0
// ===========================================================

// λ_i(0) = ∏_{j∈S, j≠i} (-j)/(i-j)  over the field (mod n)
func lagrangeCoeffAtZero(i Identifier, set []Identifier) secp.ModNScalar {
	num := modNOne()
	den := modNOne()

	ii := i.ToScalar()
	for _, j := range set {
		if j.Equal(i) {
			continue
		}

		jj := j.ToScalar()

		negj := jj.Negate() // -j
		num = *num.Mul(negj)

		//(i - j)
		den = *ii.Add(negj).Mul(&den)
	}

	denInv := den.InverseNonConst()
	return *num.Mul(denInv)
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

	var secret *secp.ModNScalar
	for i, k := range participants {
		l := lagrangeCoeffAtZero(i, ids)
		part := l.Mul(&k.s)
		secret = secret.Add(part)
	}

	return SecretKey{Scalar: *secret}, nil
}
