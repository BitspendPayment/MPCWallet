package threshold_signing

import (
	"crypto/rand"
	"io"

	thres "github.com/ArkLabsHQ/thresholdmagic/thresholdcore"

	"github.com/decred/dcrd/dcrec/secp256k1/v4"
)

type SigningNonce struct {
	hiding  *secp256k1.ModNScalar
	binding *secp256k1.ModNScalar

	commitments SigningCommitments
}

func NewNonce(secret thres.SecretShare, rng io.Reader) SigningNonce {
	hiding := generateNonce(secret, rng)
	binding := generateNonce(secret, rng)

	hidingCommitment := secp256k1.JacobianPoint{}
	bindingCommitment := secp256k1.JacobianPoint{}

	secp256k1.ScalarBaseMultNonConst(&hiding, &hidingCommitment)
	secp256k1.ScalarBaseMultNonConst(&binding, &bindingCommitment)

	commitments := SigningCommitments{
		Hiding:  hidingCommitment,
		Binding: bindingCommitment,
	}

	return SigningNonce{
		hiding:      &hiding,
		binding:     &binding,
		commitments: commitments,
	}
}

type SigningCommitments struct {
	Binding secp256k1.JacobianPoint
	Hiding  secp256k1.JacobianPoint
}

type GroupCommitmentShare struct {
	elem secp256k1.JacobianPoint
}

func (s *SigningCommitments) toGroupCommitmentShare(bindingScalar secp256k1.ModNScalar) GroupCommitmentShare {
	// sum = B_i + b_i * H_i
	var bH secp256k1.JacobianPoint

	secp256k1.ScalarMultNonConst(&bindingScalar, &s.Binding, &bH)
	sum := secp256k1.JacobianPoint{}
	secp256k1.AddNonConst(&s.Hiding, &bH, &sum)
	return GroupCommitmentShare{elem: sum}
}

func generateNonce(secret thres.SecretShare, rng io.Reader) secp256k1.ModNScalar {

	var rb [32]byte
	if rng == nil {
		rng = rand.Reader
	}
	_, _ = io.ReadFull(rng, rb[:])

	secretBytes := (*secp256k1.ModNScalar)(&secret).Bytes()

	concatenatedBytes := append(rb[:], secretBytes[:]...)

	return H3(concatenatedBytes[:])

}

type GroupCommitment struct {
	elem secp256k1.JacobianPoint
}

func ComputeGroupCommitment(
	s *SigningPackage,
	bfl BindingFactorList,
) (GroupCommitment, error) {
	identity := secp256k1.JacobianPoint{}
	groupCommitment := secp256k1.JacobianPoint{}

	n := len(s.Commitments)

	bindingScalars := make([]secp256k1.ModNScalar, 0, n)
	bindingElements := make([]secp256k1.JacobianPoint, 0, n)

	for id, comm := range s.Commitments {
		bind := comm.Binding
		hide := comm.Hiding

		// Prevent identity commitments
		if identity.EquivalentNonConst(&bind) || identity.EquivalentNonConst(&hide) {
			return GroupCommitment{}, ErrIdentityCommitment
		}

		// lookup binding factor for id
		bf, ok := bfl.Get(id)
		if !ok {
			return GroupCommitment{}, ErrUnknownIdentifier
		}

		// collect for single MSM
		bindingElements = append(bindingElements, bind)
		bindingScalars = append(bindingScalars, bf.Scalar)

		// sum hiding commitments
		temp := secp256k1.JacobianPoint{}
		secp256k1.AddNonConst(&groupCommitment, &hide, &temp)
		groupCommitment = temp
		//
	}

	// accumulated binding commitment via MSM
	acc := VartimeMultiscalarMul(bindingScalars, bindingElements)
	temp := secp256k1.JacobianPoint{}
	secp256k1.AddNonConst(&groupCommitment, acc, &temp)
	groupCommitment = temp

	return GroupCommitment{elem: groupCommitment}, nil
}
