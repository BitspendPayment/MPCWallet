package threshold_signing

import (
	thres "github.com/ArkLabsHQ/thresholdmagic/thresholdcore"
	"github.com/decred/dcrd/dcrec/secp256k1/v4"
)

// VartimeMultiscalarMul is a simplified version — you’ll need to adapt for speed.
func VartimeMultiscalarMul(scalars []secp256k1.ModNScalar, elems []secp256k1.JacobianPoint) *secp256k1.JacobianPoint {
	if len(scalars) != len(elems) {
		return nil
	}
	acc := secp256k1.JacobianPoint{}
	for i := range scalars {
		temp := secp256k1.JacobianPoint{}
		secp256k1.ScalarMultNonConst(&scalars[i], &elems[i], &temp)

		secp256k1.AddNonConst(&acc, &temp, &acc)
	}
	return &acc
}

func SerializePointCompressed(point secp256k1.JacobianPoint) []byte {
	affine := secp256k1.JacobianPoint{}
	affine.Set(&point)
	affine.ToAffine()
	pk := secp256k1.NewPublicKey(&affine.X, &affine.Y)
	return pk.SerializeCompressed()
}

func DeriveInterpolatingValue(id thres.Identifier, pkg *SigningPackage) *secp256k1.ModNScalar {
	ids := make([]thres.Identifier, 0, len(pkg.Commitments))
	for k := range pkg.Commitments {
		ids = append(ids, k)
	}
	return thres.LagrangeCoeffAtZero(id, ids)
}
