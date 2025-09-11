package threshold_signing

import (
	thres "github.com/ArkLabsHQ/thresholdmagic/thresholdcore"
	"github.com/decred/dcrd/dcrec/secp256k1/v4"
)

type SignatureShare struct {
	s secp256k1.ModNScalar
}

func (s *SignatureShare) verify(id thres.Identifier, verifyingShare thres.VerifyingShare, lambda_i secp256k1.ModNScalar, challenge secp256k1.ModNScalar, groupCommitmentShare GroupCommitmentShare) bool {
	// left = s_i * G
	left := secp256k1.JacobianPoint{}
	secp256k1.ScalarBaseMultNonConst(&s.s, &left)

	// right = R_i + (λ_i * e) * Y_i
	//verifyiongShareD := (*secp256k1.ModNScalar)(&verifyingShare)

	lambdaE := lambda_i.Mul(&challenge)
	temp := secp256k1.JacobianPoint{}

	secp256k1.ScalarMultNonConst(lambdaE, &verifyingShare, &temp)

	right := secp256k1.JacobianPoint{}
	secp256k1.AddNonConst(&groupCommitmentShare.elem, &temp, &right)

	return left.EquivalentNonConst(&right)

}

func ComputeSignatureShare(nonces SigningNonce, bindingFactor BindingFactor, lambdaI secp256k1.ModNScalar, keyPackage thres.KeyPackage, challenge secp256k1.ModNScalar) SignatureShare {
	// z_i = k_i + (λ_i * x_i * e) + (b_i * ρ_i)

	keyPackageScalar := (*secp256k1.ModNScalar)(&keyPackage.SecretShare)
	lambdaX := lambdaI.Mul(keyPackageScalar)

	lambdaXE := lambdaX.Mul(&challenge)

	bindingRho := bindingFactor.Scalar.Mul(nonces.binding)

	z := secp256k1.ModNScalar{}
	z.Add2(nonces.hiding, lambdaXE).Add(bindingRho)

	return SignatureShare{s: z}
}
