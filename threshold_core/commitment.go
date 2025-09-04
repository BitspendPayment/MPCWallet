package thresholdcore

import secp "github.com/decred/dcrd/dcrec/secp256k1/v4"

type CoefficientCommitment struct {
	E secp.JacobianPoint
}

func newCoefficientCommitment(e secp.JacobianPoint) CoefficientCommitment {
	return CoefficientCommitment{E: e}
}
func (cc CoefficientCommitment) Serialize() ([]byte, error) { return elemSerializeCompressed(cc.E) }
func (cc *CoefficientCommitment) Deserialize(b []byte) error {
	e, err := elemDeserializeCompressed(b)
	if err != nil {
		return err
	}
	cc.E = e
	return nil
}

type VerifiableSecretSharingCommitment struct {
	Coeffs []CoefficientCommitment
}

func newVSSCommitment(coeffs []CoefficientCommitment) VerifiableSecretSharingCommitment {
	return VerifiableSecretSharingCommitment{Coeffs: coeffs}
}
func (v VerifiableSecretSharingCommitment) Serialize() ([][]byte, error) {
	out := make([][]byte, len(v.Coeffs))
	for i := range v.Coeffs {
		b, err := v.Coeffs[i].Serialize()
		if err != nil {
			return nil, err
		}
		out[i] = b
	}
	return out, nil
}
func (v VerifiableSecretSharingCommitment) SerializeWhole() ([]byte, error) {
	parts, err := v.Serialize()
	if err != nil {
		return nil, err
	}
	var cat []byte
	for _, p := range parts {
		cat = append(cat, p...)
	}
	return cat, nil
}
func (v *VerifiableSecretSharingCommitment) Deserialize(parts [][]byte) error {
	coeffs := make([]CoefficientCommitment, 0, len(parts))
	for _, p := range parts {
		var cc CoefficientCommitment
		if err := cc.Deserialize(p); err != nil {
			return err
		}
		coeffs = append(coeffs, cc)
	}
	*v = newVSSCommitment(coeffs)
	return nil
}

// Sum commitments across participants to a single group commitment.
func sumCommitments(commitments []*VerifiableSecretSharingCommitment) (VerifiableSecretSharingCommitment, error) {
	if len(commitments) == 0 {
		return VerifiableSecretSharingCommitment{}, ErrIncorrectNumberOfCommit
	}
	l := len(commitments[0].Coeffs)
	group := make([]CoefficientCommitment, l)
	for i := 0; i < l; i++ {
		group[i] = newCoefficientCommitment(secp.JacobianPoint{})
	}
	for _, c := range commitments {
		if len(c.Coeffs) != l {
			return VerifiableSecretSharingCommitment{}, ErrIncorrectNumberOfCommit
		}
		for i := 0; i < l; i++ {
			group[i] = newCoefficientCommitment(
				elemAdd(group[i].E, c.Coeffs[i].E),
			)
		}
	}
	return newVSSCommitment(group), nil
}
