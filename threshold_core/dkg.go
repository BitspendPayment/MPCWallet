package thresholdcore

import (
	"crypto/sha256"
	"io"
	"sort"

	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
)

//! [Pedersen's DKG]: https://link.springer.com/chapter/10.1007/3-540-46416-6_47
//! [Feldman's VSS]: https://www.cs.umd.edu/~gasarch/TOPICS/secretsharing/feldmanVSS.pdf

// Round1Package is broadcast to all participants after part1.
type Round1Package struct {
	Commitment       VerifiableSecretSharingCommitment
	ProofOfKnowledge Signature
}

// Signature is σ = (R, z) where R = g^k and z = k + a_{i0} * c.
type Signature struct {
	R secp.JacobianPoint
	Z secp.ModNScalar
}

// Challenge wrapper (scalar). Kept as a type for clarity.
type Challenge struct {
	C secp.ModNScalar
}

// Compute a SigningShare from polynomial coefficients for a specific peer ID.
func secretShareFromCoefficients(coeffs []secp.ModNScalar, peer Identifier) SecretShare {
	s := evaluatePolynomial(peer, coeffs)
	return newSecretShare(s)
}

// Round1SecretPackage must be kept locally by the participant after part1.
type Round1SecretPackage struct {
	Identifier   Identifier
	Coefficients []secp.ModNScalar // includes a_{i0} as the first element
	Commitment   VerifiableSecretSharingCommitment
	MinSigners   uint16
	MaxSigners   uint16
}

func DKGPart1(
	identifier Identifier,
	maxSigners, minSigners uint16,
	secretKey SecretKey,
	r io.Reader,
) (Round1SecretPackage, Round1Package, error) {

	if err := validateNumOfSigners(minSigners, maxSigners); err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	// t-1 random coeffs
	coeffOnly, err := generateCoefficients(int(minSigners) - 1)
	if err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	// coeffs = [a_{i0}=key.Scalar, coeffOnly...], plus commitments φ_{ij} = g^{a_{ij}}
	coeffs, commitment, err := generateSecretPolynomial(&secretKey.Scalar, maxSigners, minSigners, coeffOnly)
	if err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	// σ_i = PoK for a_{i0}
	sig, err := computeProofOfKnowledge(identifier, coeffs, &commitment, r)
	if err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	secretPkg := Round1SecretPackage{
		Identifier:   identifier,
		Coefficients: coeffs,
		Commitment:   commitment,
		MinSigners:   minSigners,
		MaxSigners:   maxSigners,
	}
	pubPkg := Round1Package{
		Commitment:       commitment,
		ProofOfKnowledge: sig,
	}
	return secretPkg, pubPkg, nil
}

// σ = (R, z) with R = g^k, z = k + a_{i0} * c, c = challenge(i, φ_{i0}, R)
func computeProofOfKnowledge(
	identifier Identifier,
	coefficients []secp.ModNScalar,
	commitment *VerifiableSecretSharingCommitment,
	r io.Reader,
) (Signature, error) {

	// k, R = g^k
	k, R, err := generateNonce(r)
	if err != nil {
		return Signature{}, err
	}
	// φ_{i0} is the first coefficient commitment → verifying key
	vk, err := VerifyingKeyFromCommitment(*commitment)
	if err != nil {
		return Signature{}, err
	}
	// c = H(i, φ_{i0}, R)
	chal, err := dkgChallenge(identifier, vk, R)
	if err != nil {
		return Signature{}, err
	}
	// a_{i0}
	if len(coefficients) == 0 {
		return Signature{}, ErrInvalidCoefficients
	}
	a0 := coefficients[0]

	// z = k + a0 * c
	zc := modNMul(&a0, &chal.C)
	z := modNAdd(&k, &zc)

	return Signature{R: R, Z: z}, nil
}

// Verify σℓ = (Rℓ, μℓ): check Rℓ ?= g^{μℓ} · φ_{ℓ0}^{-cℓ}
func verifyProofOfKnowledge(
	identifier Identifier, // ℓ
	commitment *VerifiableSecretSharingCommitment,
	sig *Signature,
) error {

	// φ_{ℓ0}
	vk, err := VerifyingKeyFromCommitment(*commitment)
	if err != nil {
		return err
	}

	// cℓ = H(ℓ, φ_{ℓ0}, Rℓ)
	chal, err := dkgChallenge(identifier, vk, sig.R)
	if err != nil {
		return err
	}

	// right = g^{μℓ} + (φ_{ℓ0} * (-cℓ))
	left := sig.R
	mu := sig.Z

	gmu := elemBaseMul(&mu)
	cneg := chal.C
	cneg.Negate()

	phiNeg := elemMul(vk.E, &cneg)
	right := elemAdd(gmu, phiNeg)

	lb, _ := elemSerializeCompressed(left)
	rb, _ := elemSerializeCompressed(right)

	eq := len(lb) == len(rb)
	if eq {
		for i := range lb {
			if lb[i] != rb[i] {
				eq = false
				break
			}
		}
	}
	if !eq {
		return ErrInvalidSecretShare // reusing; or define ErrInvalidProofOfKnowledge
	}
	return nil
}

// challenge(i, VK, R) = H(i || enc(VK) || enc(R)) reduced mod n.
func dkgChallenge(
	identifier Identifier,
	verifyingKey VerifyingKey,
	R secp.JacobianPoint,
) (Challenge, error) {
	var pre []byte

	pre = append(pre, identifier.Serialize()...)

	vkSer, err := elemSerializeCompressed(verifyingKey.E)
	if err != nil {
		return Challenge{}, err
	}
	pre = append(pre, vkSer...)

	rSer, err := elemSerializeCompressed(R)
	if err != nil {
		return Challenge{}, err
	}
	pre = append(pre, rSer...)

	// Domain-separated hash if you want: H("FROST-DKG" || pre)
	sum := sha256.Sum256(pre)
	return Challenge{C: modNFromBytesAllowZero(sum[:])}, nil
}

// -----------------------------------------------------------------------------
// DKG Round 2
// -----------------------------------------------------------------------------

// Round2Package is sent privately to each recipient ℓ with the share f_i(ℓ).
type Round2Package struct {
	SecretShare SecretShare // f_i(ℓ)
}

// Round2SecretPackage is kept locally after part2 (holds f_i(i)).
type Round2SecretPackage struct {
	Identifier  Identifier
	Commitment  VerifiableSecretSharingCommitment
	SecretShare secp.ModNScalar // f_i(i)
	MinSigners  uint16
	MaxSigners  uint16
}

// part2 consumes my Round1SecretPackage and all peers' Round1Package.
// Returns my Round2SecretPackage plus per-peer Round2Package to send.
func DKGPart2(
	secretPkg Round1SecretPackage,
	round1Pkgs map[Identifier]Round1Package,
) (Round2SecretPackage, map[Identifier]Round2Package, error) {

	if len(round1Pkgs) != int(secretPkg.MaxSigners-1) {
		return Round2SecretPackage{}, nil, ErrIncorrectNumberOfPackages
	}
	for _, p := range round1Pkgs {
		if len(p.Commitment.Coeffs) != int(secretPkg.MinSigners) {
			return Round2SecretPackage{}, nil, ErrIncorrectNumberOfCommitments
		}
	}

	out := make(map[Identifier]Round2Package, len(round1Pkgs))
	for senderID, pkg := range round1Pkgs {
		// Verify PoK from each peer
		if err := verifyProofOfKnowledge(senderID, &pkg.Commitment, &pkg.ProofOfKnowledge); err != nil {
			return Round2SecretPackage{}, nil, err
		}

		// Build f_i(ℓ) for each recipient ℓ
		share := secretShareFromCoefficients(secretPkg.Coefficients, senderID)
		out[senderID] = Round2Package{
			SecretShare: share,
		}
	}

	// Keep f_i(i) for myself
	fii := evaluatePolynomial(secretPkg.Identifier, secretPkg.Coefficients)

	return Round2SecretPackage{
		Identifier:  secretPkg.Identifier,
		Commitment:  secretPkg.Commitment,
		SecretShare: fii,
		MinSigners:  secretPkg.MinSigners,
		MaxSigners:  secretPkg.MaxSigners,
	}, out, nil
}

// DKGPart3 produces my KeyPackage and the PublicKeyPackage for all participants.
// round1Pkgs must be the same map used in DKGPart2; round2Pkgs are the shares I received.
func DKGPart3(
	r1Secret *Round1SecretPackage,
	r2Secret *Round2SecretPackage,
	round1Pkgs map[Identifier]Round1Package,
	round2Pkgs map[Identifier]Round2Package,
) (KeyPackage, PublicKeyPackage, error) {

	if len(round1Pkgs) != int(r2Secret.MaxSigners-1) {
		return KeyPackage{}, PublicKeyPackage{}, ErrIncorrectNumberOfPackages
	}
	if len(round1Pkgs) != len(round2Pkgs) {
		return KeyPackage{}, PublicKeyPackage{}, ErrIncorrectNumberOfPackages
	}
	for id := range round1Pkgs {
		if _, ok := round2Pkgs[id]; !ok {
			return KeyPackage{}, PublicKeyPackage{}, ErrIncorrectPackage
		}
	}

	// s_i = sum_{ℓ} f_ℓ(i)
	si := modNZero()

	for senderID, pkg2 := range round2Pkgs {
		// Verify g^{f_ℓ(i)} ?= ∑ φ_{ℓk} i^k using the peer's Round1 commitment
		r1, ok := round1Pkgs[senderID]
		if !ok {
			return KeyPackage{}, PublicKeyPackage{}, ErrIncorrectPackage
		}
		temp := ThresholdShare{
			Identifier: r2Secret.Identifier, // i (me)
			SecretSh:   pkg2.SecretShare,
			Commitment: r1.Commitment, // φ_ℓ
		}
		if _, _, err := temp.Verify(); err != nil {
			// identify culprit by returning an error tied to senderID if you like
			return KeyPackage{}, PublicKeyPackage{}, err
		}
		si = modNAdd(&si, &pkg2.SecretShare.s)
	}

	// Add my own f_i(i)
	si = modNAdd(&si, &r2Secret.SecretShare)
	secretShare := newSecretShare(si)

	// Y_i = g^{s_i}
	verifyingShare := verifyingShareFromSigning(secretShare)

	// Build public key package from all commitments (peers + mine)
	commitMap := make(map[Identifier]*VerifiableSecretSharingCommitment, len(round1Pkgs)+1)
	for id, p := range round1Pkgs {
		c := p.Commitment // copy
		commitMap[id] = &c
	}
	commitMap[r2Secret.Identifier] = &r2Secret.Commitment

	publicKeyPackage, err := PKPFromDKGCommitments(commitMap)
	if err != nil {
		return KeyPackage{}, PublicKeyPackage{}, err
	}

	keyPackage := KeyPackage{
		r2Secret.Identifier,
		secretShare,
		verifyingShare,
		publicKeyPackage.VerifyingKey,
		r2Secret.MinSigners,
	}

	// If you need a post-DKG hook, call it here. Otherwise, return as-is.
	return keyPackage, publicKeyPackage, nil
}

type KeyPackage struct {
	Identifier     Identifier
	SecretShare    SecretShare
	VerifyingShare VerifyingShare
	VerifyingKey   VerifyingKey
	MinSigners     uint16
}

// Build from DKG commitments (one per participant), summing to a group commitment
func PKPFromDKGCommitments(commits map[Identifier]*VerifiableSecretSharingCommitment) (PublicKeyPackage, error) {
	ids := make([]Identifier, 0, len(commits))
	list := make([]*VerifiableSecretSharingCommitment, 0, len(commits))
	for id, c := range commits {
		ids = append(ids, id)
		list = append(list, c)
	}
	group, err := sumCommitments(list)
	if err != nil {
		return PublicKeyPackage{}, err
	}
	// Sort ids for determinism
	sort.Slice(ids, func(i, j int) bool { return ids[i].Less(ids[j]) })
	return PKPFromCommitment(ids, group)
}

// PublicKeyPackage is the public bundle
type PublicKeyPackage struct {
	VerifyingShares map[Identifier]VerifyingShare
	VerifyingKey    VerifyingKey
}

// Build from a single (group) commitment and a set of identifiers
func PKPFromCommitment(ids []Identifier, commit VerifiableSecretSharingCommitment) (PublicKeyPackage, error) {
	vmap := make(map[Identifier]VerifyingShare, len(ids))
	for _, id := range ids {
		vmap[id] = VerifyingShareFromCommitment(id, &commit)
	}
	vk, err := VerifyingKeyFromCommitment(commit)
	if err != nil {
		return PublicKeyPackage{}, err
	}
	return PublicKeyPackage{vmap, vk}, nil
}
