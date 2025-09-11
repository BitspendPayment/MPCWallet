package thresholdcore

import (
	"encoding/hex"
	"encoding/json"

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

func (vk VerifyingKey) Verify(message []byte, signature Signature) bool {

	left := elemBaseMul(&signature.Z) // g * z
	right := secp.JacobianPoint{}

	scalerMessage := secp.ModNScalar{}
	scalerMessage.SetByteSlice(message)

	// m * E
	temp := elemMul(vk.E, &scalerMessage)

	secp.AddNonConst(&signature.R, &temp, &right) // R + m * E

	return left.EquivalentNonConst(&right)
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
		l := LagrangeCoeffAtZero(i, ids)      // returns ModNScalar
		part := l.Mul((*secp.ModNScalar)(&k)) // convert SecretShare to *secp.ModNScalar
		secret.Add(part)                      // secret += part
	}

	return SecretKey{Scalar: secret}, nil
}

func (pkp PublicKeyPackage) MarshalJSON() ([]byte, error) {
	wireShares := make(map[string]string, len(pkp.VerifyingShares))
	for id, share := range pkp.VerifyingShares {
		key := hex.EncodeToString(id.Serialize())

		var affinePoint secp.JacobianPoint
		affinePoint.Set(&share)
		affinePoint.ToAffine()

		bytes := secp.NewPublicKey(&affinePoint.X, &affinePoint.Y).SerializeCompressed()

		wireShares[key] = hex.EncodeToString(bytes)
	}
	return json.Marshal(struct {
		VerifyingShares map[string]string `json:"verifyingShares"`
		VerifyingKey    VerifyingKey      `json:"verifyingKey"`
	}{
		VerifyingShares: wireShares,
		VerifyingKey:    pkp.VerifyingKey,
	})
}

func (pkp *PublicKeyPackage) UnmarshalJSON(data []byte) error {
	var wire struct {
		VerifyingShares map[string]string `json:"verifyingShares"`
		VerifyingKey    VerifyingKey      `json:"verifyingKey"`
	}
	if err := json.Unmarshal(data, &wire); err != nil {
		return err
	}

	out := make(map[Identifier]VerifyingShare, len(wire.VerifyingShares))
	for idHex, ptHex := range wire.VerifyingShares {
		// id
		idBytes, err := hex.DecodeString(idHex)
		if err != nil {
			return err
		}
		id, err := DeserializeIdentifier(idBytes)
		if err != nil {
			return err
		}
		// point
		ptBytes, err := hex.DecodeString(ptHex)
		if err != nil {
			return err
		}
		ptKey, err := secp.ParsePubKey(ptBytes) // accepts compressed or uncompressed
		if err != nil {
			return err
		}
		var pt secp.JacobianPoint
		ptKey.AsJacobian(&pt)

		out[id] = VerifyingShare(pt)
	}
	pkp.VerifyingShares = out
	pkp.VerifyingKey = wire.VerifyingKey
	return nil
}
