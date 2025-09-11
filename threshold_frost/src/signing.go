package threshold_signing

import (
	thres "github.com/ArkLabsHQ/thresholdmagic/thresholdcore"
	"github.com/decred/dcrd/dcrec/secp256k1/v4"
)

type SigningPackage struct {
	Commitments map[thres.Identifier]SigningCommitments
	Message     []byte
}

func (s *SigningPackage) SigningCommitment(id thres.Identifier) (SigningCommitments, bool) {
	c, ok := s.Commitments[id]
	return c, ok
}

func (s *SigningPackage) encodeGroupCommitmentList() []byte {
	groupCommitmentList := s.Commitments

	var buf []byte
	for id, comm := range groupCommitmentList {
		idSerialised := id.Serialize()

		buf = append(buf, idSerialised...)

		hidingBytes := SerializePointCompressed(comm.Hiding)
		buf = append(buf, hidingBytes...)

		bindingBytes := SerializePointCompressed(comm.Binding)
		buf = append(buf, bindingBytes...)
	}

	return buf
}

func (s *SigningPackage) bindingFactorPreimages(
	vk thres.VerifyingKey) ([]BindingFactorPreimage, error) {
	var prefix []byte

	var affinePoint secp256k1.JacobianPoint
	affinePoint.Set(&vk.E)
	affinePoint.ToAffine()

	vkBytes := secp256k1.NewPublicKey(&affinePoint.X, &affinePoint.Y).SerializeCompressed()

	prefix = append(prefix, vkBytes...)

	// H4(message)
	h4 := H4(s.Message)
	prefix = append(prefix, h4...)

	// H5(encode_group_commitments(commitments))
	encGC := s.encodeGroupCommitmentList()
	h5 := H5(encGC)
	prefix = append(prefix, h5...)

	// build per-identifier preimages
	out := make([]BindingFactorPreimage, 0, len(s.Commitments))

	for id := range s.Commitments {
		buf := make([]byte, 0, len(prefix)+len(id.Serialize()))
		buf = append(buf, prefix...)
		buf = append(buf, id.Serialize()...)
		out = append(out, BindingFactorPreimage{
			ID:       id,
			Preimage: buf,
		})
	}
	return out, nil
}

// / Performed once by each participant selected for the signing operation.
// /
// / Implements [`sign`] from the spec.
// /
// / Receives the message to be signed and a set of signing commitments and a set
// / of randomizing commitments to be used in that signing operation, including
// / that for this participant.
// /
// / Assumes the participant has already determined which nonce corresponds with
// / the commitment that was assigned by the coordinator in the SigningPackage.
// /
// / [`sign`]: https://datatracker.ietf.org/doc/html/rfc9591#name-round-two-signature-share-g
func Sign(
	signingPackage SigningPackage, signingNonce SigningNonce, keyPackage thres.KeyPackage) (*SignatureShare, error) {

	if len(signingPackage.Commitments) < int(keyPackage.MinSigners) {
		// Not enough participants to sign
		return nil, thres.ErrIncorrectNumberOfCommitments
	}

	commitment := signingPackage.Commitments[keyPackage.Identifier]

	if signingNonce.commitments != commitment {
		// Nonce does not match commitment
		return nil, ErrInvalidCommitment
	}

	bindingFactorList, err := ComputeBindingFactorList(&signingPackage, keyPackage.VerifyingKey)
	if err != nil {
		return nil, ErrIncorrectBindingFactorPreimages
	}

	groupCommitment, err := ComputeGroupCommitment(&signingPackage, bindingFactorList)

	lambda_i := DeriveInterpolatingValue(keyPackage.Identifier, &signingPackage)

	challenge, err := ComputeChallenge(&groupCommitment.elem, keyPackage.VerifyingKey, signingPackage.Message)
	if err != nil {
		return nil, err
	}

	signatureShare := ComputeSignatureShare(signingNonce, bindingFactorList.F[keyPackage.Identifier], *lambda_i, keyPackage, *challenge)

	return &signatureShare, nil
}

func ComputeChallenge(R *secp256k1.JacobianPoint, vk thres.VerifyingKey, message []byte) (*secp256k1.ModNScalar, error) {
	// H2(encode_point(R) || encode_point(Y) || message)
	var affineR secp256k1.JacobianPoint
	affineR.Set(R)
	affineR.ToAffine()
	RBytes := secp256k1.NewPublicKey(&affineR.X, &affineR.Y).SerializeCompressed()

	var affineY secp256k1.JacobianPoint
	affineY.Set(&vk.E)
	affineY.ToAffine()
	YBytes := secp256k1.NewPublicKey(&affineY.X, &affineY.Y).SerializeCompressed()

	prefix := append(RBytes, YBytes...)
	prefix = append(prefix, message...)

	e := H2(prefix)
	return &e, nil
}

// Aggregate sums signature shares into a single Schnorr signature and verifies it
// against the group public key. Optionally, you can do cheater-detection by
// verifying each share if the final signature verification fails.
func Aggregate(
	signingPackage *SigningPackage,
	signatureShares map[thres.Identifier]SignatureShare, // key = string(id.Serialize())
	pubkeys thres.PublicKeyPackage,
) (*thres.Signature, error) {
	// 1) identifier set must match
	if len(signingPackage.Commitments) != len(signatureShares) {
		return nil, ErrUnknownIdentifier
	}
	for id, _ := range signingPackage.Commitments {
		if _, ok := signatureShares[id]; !ok {
			return nil, ErrUnknownIdentifier
		}

		if _, ok := pubkeys.VerifyingShares[id]; !ok {
			return nil, ErrUnknownIdentifier
		}
	}

	bfl, err := ComputeBindingFactorList(signingPackage, pubkeys.VerifyingKey)
	if err != nil {
		return nil, err
	}
	groupCommitment, err := ComputeGroupCommitment(signingPackage, bfl)
	if err != nil {
		return nil, err
	}

	// aggregate z = sum(z_i)
	var z secp256k1.ModNScalar // zero by default
	for _, sh := range signatureShares {
		// z = z + z_i (mod n); ModNScalar.Add mutates receiver and returns it
		z.Add(&sh.s)
	}

	sig := &thres.Signature{
		R: groupCommitment.elem,
		Z: z,
	}

	//verify final signature with the group verifying key
	if pubkeys.VerifyingKey.Verify(signingPackage.Message, *sig) {

		if err2 := DetectCheater(&groupCommitment, &pubkeys, signingPackage, signatureShares, bfl); err2 != nil {
			return nil, err2
		}
		return sig, err
	}

	return sig, ErrorWrongSignature
}

func DetectCheater(
	groupCommitment *GroupCommitment,
	pubkeys *thres.PublicKeyPackage,
	signingPackage *SigningPackage,
	signatureShares map[thres.Identifier]SignatureShare,
	bfl BindingFactorList,
) error {
	// Compute per-message challenge
	e, err := ComputeChallenge(&groupCommitment.elem, pubkeys.VerifyingKey, signingPackage.Message)
	if err != nil {
		return err
	}

	// Verify each share
	for id, sshare := range signatureShares {
		verShare, ok := pubkeys.VerifyingShares[id]
		if !ok {
			return ErrUnknownIdentifier
		}

		if err := verifySignatureSharePrecomputed(
			id,
			signingPackage,
			bfl,
			groupCommitment,
			&sshare,
			&verShare,
			e,
		); err != nil {
			return err
		}
	}

	// If all passed, fall back to a generic error to mirror Rust's "should not reach"
	return ErrorInvalidSignature
}

func VerifySignatureShare(
	identifier thres.Identifier,
	verifyingShare *secp256k1.JacobianPoint,
	signatureShare *SignatureShare,
	signingPackage *SigningPackage,
	verifyingKey thres.VerifyingKey,
) error {
	// Binding factors and group commitment
	bfl, err := ComputeBindingFactorList(signingPackage, verifyingKey)
	if err != nil {
		return err
	}
	groupCommitment, err := ComputeGroupCommitment(signingPackage, bfl)
	if err != nil {
		return err
	}

	// Challenge
	e, err := ComputeChallenge(&groupCommitment.elem, verifyingKey, signingPackage.Message)
	if err != nil {
		return err
	}

	// Final check
	return verifySignatureSharePrecomputed(
		identifier,
		signingPackage,
		bfl,
		&groupCommitment,
		signatureShare,
		verifyingShare,
		e,
	)
}

// verifySignatureSharePrecomputed performs the share check with precomputed values.
func verifySignatureSharePrecomputed(
	signatureShareIdentifier thres.Identifier,
	signingPackage *SigningPackage,
	bfl BindingFactorList,
	groupCommitment *GroupCommitment,
	signatureShare *SignatureShare,
	verifyingShare *secp256k1.JacobianPoint,
	challenge *secp256k1.ModNScalar,
) error {

	ids := make([]thres.Identifier, 0, len(signingPackage.Commitments))
	for k := range signingPackage.Commitments {
		ids = append(ids, k)
	}
	// λ_i
	lambdaI := thres.LagrangeCoeffAtZero(signatureShareIdentifier, ids)

	// ρ_i for this identifier
	bf, ok := bfl.Get(signatureShareIdentifier)
	if !ok {
		return ErrUnknownIdentifier
	}

	// commitments for this signer
	comm, ok := signingPackage.Commitments[signatureShareIdentifier]
	if !ok {
		return ErrUnknownIdentifier
	}

	// R_i share for this signer
	Rshare := comm.toGroupCommitmentShare(bf.Scalar)

	// Relation check
	res := signatureShare.verify(
		signatureShareIdentifier,
		*verifyingShare,
		*lambdaI,
		*challenge,
		Rshare,
	)

	if !res {
		return ErrorInvalidSignature
	}

	return nil
}
