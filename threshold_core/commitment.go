package thresholdcore

import secp "github.com/decred/dcrd/dcrec/secp256k1/v4"

type CoefficientCommitment = secp.JacobianPoint
type VerifiableSecretSharingCommitment struct {
	Coeffs []CoefficientCommitment
}

// RHS of VSS verification: sum_k φ_k * (i^k)
func (v VerifiableSecretSharingCommitment) GetVerifyingShare(id Identifier) VerifyingShare {
	x := id.ToScalar()
	// i^0 = 1
	itok := modNOne()

	sum := VerifyingShare{}
	for k := 0; k < len(v.Coeffs); k++ {
		term := elemMul(v.Coeffs[k], &itok)
		sum = elemAdd(sum, term)
		// next power
		itok.Mul(&x)
	}
	return sum
}

func (vss VerifiableSecretSharingCommitment) ToVerifyingKey() (VerifyingKey, error) {
	if len(vss.Coeffs) == 0 {
		return VerifyingKey{}, ErrInvalidCommitVector
	}
	return VerifyingKey{E: vss.Coeffs[0]}, nil
}

// Sum commitments across participants to a single group commitment.
func sumCommitments(commitments []*VerifiableSecretSharingCommitment) (VerifiableSecretSharingCommitment, error) {
	if len(commitments) == 0 {
		return VerifiableSecretSharingCommitment{}, ErrIncorrectNumberOfCommit
	}
	l := len(commitments[0].Coeffs)
	group := make([]CoefficientCommitment, l)
	for i := 0; i < l; i++ {
		group[i] = CoefficientCommitment(secp.JacobianPoint{})
	}
	for _, c := range commitments {
		if len(c.Coeffs) != l {
			return VerifiableSecretSharingCommitment{}, ErrIncorrectNumberOfCommit
		}
		for i := 0; i < l; i++ {
			group[i] = CoefficientCommitment(
				elemAdd(group[i], c.Coeffs[i]),
			)
		}
	}
	return VerifiableSecretSharingCommitment{group}, nil
}
