package thresholdcore

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"sort"

	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
)

//! [Pedersen's DKG]: https://link.springer.com/chapter/10.1007/3-540-46416-6_47
//! [Feldman's VSS]: https://www.cs.umd.edu/~gasarch/TOPICS/secretsharing/feldmanVSS.pdf

// Round1Package is broadcast to all participants after part1.
type Round1Package struct {
	Commitment       VerifiableSecretSharingCommitment `json:"commitment"`
	ProofOfKnowledge Signature                         `json:"proofOfKnowledge"`
}

// Signature is σ = (R, z) where R = g^k and z = k + a_{i0} * c.
type Signature struct {
	R secp.JacobianPoint
	Z secp.ModNScalar
}

func (s Signature) MarshalJSON() ([]byte, error) {
	var affinePoint secp.JacobianPoint
	affinePoint.Set(&s.R)
	affinePoint.ToAffine()

	rb := secp.NewPublicKey(&affinePoint.X, &affinePoint.Y).SerializeCompressed()

	zb := s.Z.Bytes() // [32]byte big-endian
	payload := struct {
		R string `json:"R"` // hex(SEC1 compressed)
		Z string `json:"Z"` // hex(32B scalar)
	}{
		R: hex.EncodeToString(rb),
		Z: hex.EncodeToString(zb[:]),
	}
	return json.Marshal(payload)
}

func (s *Signature) UnmarshalJSON(data []byte) error {
	var payload struct {
		R string `json:"R"`
		Z string `json:"Z"`
	}
	if err := json.Unmarshal(data, &payload); err != nil {
		return err
	}

	// R
	rb, err := hex.DecodeString(payload.R)
	if err != nil {
		return err
	}
	pk, err := secp.ParsePubKey(rb) // accepts compressed or uncompressed
	if err != nil {
		return err
	}
	var j secp.JacobianPoint
	pk.AsJacobian(&j)

	s.R = j

	// Z
	zb, err := hex.DecodeString(payload.Z)
	if err != nil {
		return err
	}
	var z secp.ModNScalar
	_ = z.SetByteSlice(zb) // reduce mod n (accepts various lengths)
	s.Z = z

	return nil
}

// Challenge wrapper (scalar). Kept as a type for clarity.
type Challenge struct {
	C secp.ModNScalar
}

// Compute a SigningShare from polynomial coefficients for a specific peer ID.
func secretShareFromCoefficients(coeffs []secp.ModNScalar, peer Identifier) SecretShare {
	s := evaluatePolynomial(peer, coeffs)
	return SecretShare(s)
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
	coffiecients []secp.ModNScalar,
	r io.Reader,
) (Round1SecretPackage, Round1Package, error) {

	if err := validateNumOfSigners(minSigners, maxSigners); err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	// coeffs = [a_{i0}=key.Scalar, coeffOnly...], plus commitments φ_{ij} = g^{a_{ij}}
	coeffs, commitment, err := generateSecretPolynomial(&secretKey.Scalar, maxSigners, minSigners, coffiecients)
	if err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	verifyingCommit := VerifiableSecretSharingCommitment{commitment}
	verifyingKey, err := verifyingCommit.ToVerifyingKey()
	if err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	// σ_i = PoK for a_{i0}
	sig, err := computeProofOfKnowledge(identifier, coeffs, verifyingKey, r)
	if err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	secretPkg := Round1SecretPackage{
		Identifier:   identifier,
		Coefficients: coeffs,
		Commitment:   VerifiableSecretSharingCommitment{commitment},
		MinSigners:   minSigners,
		MaxSigners:   maxSigners,
	}
	pubPkg := Round1Package{
		Commitment:       VerifiableSecretSharingCommitment{commitment},
		ProofOfKnowledge: sig,
	}
	return secretPkg, pubPkg, nil
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
	SecretShare SecretShare `json:"-"` // f_i(ℓ)
}

// Marshal as: {"secretShare":"<hex 32B>"}
func (p Round2Package) MarshalJSON() ([]byte, error) {
	zb := (*secp.ModNScalar)(&p.SecretShare).Bytes() // [32]byte big-endian
	wire := struct {
		SecretShare string `json:"secretShare"`
	}{
		SecretShare: hex.EncodeToString(zb[:]),
	}
	return json.Marshal(wire)
}

// Unmarshal from: {"secretShare":"<hex 32B>"}
func (p *Round2Package) UnmarshalJSON(data []byte) error {
	var wire struct {
		SecretShare string `json:"secretShare"`
	}
	if err := json.Unmarshal(data, &wire); err != nil {
		return err
	}
	b, err := hex.DecodeString(wire.SecretShare)
	if err != nil {
		return err
	}
	var s secp.ModNScalar
	_ = s.SetByteSlice(b) // reduces mod n; accepts various lengths
	p.SecretShare = SecretShare(s)
	return nil
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

		verifyingKey, err := pkg.Commitment.ToVerifyingKey()
		if err != nil {
			return Round2SecretPackage{}, nil, err
		}

		if err := verifyProofOfKnowledge(senderID, verifyingKey, &pkg.ProofOfKnowledge); err != nil {
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
		si.Add((*secp.ModNScalar)(&pkg2.SecretShare))
	}

	// Add my own f_i(i)
	si.Add(&r2Secret.SecretShare)
	secretShare := SecretShare(si)

	// Y_i = g^{s_i}
	verifyingShare := elemBaseMul((*secp.ModNScalar)(&secretShare))

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
		vmap[id] = commit.GetVerifyingShare(id)
	}
	vk, err := commit.ToVerifyingKey()
	if err != nil {
		return PublicKeyPackage{}, err
	}
	return PublicKeyPackage{vmap, vk}, nil
}

// -----------------------------------------------------------------------------
// Refresh DKG - Part 1
// -----------------------------------------------------------------------------

// DKGRefreshPart1 generates a zero-secret "refreshing" polynomial, removes the
// identity commitment from the public package, and produces the Round 1 outputs.
func DKGRefreshPart1(
	identifier Identifier,
	maxSigners, minSigners uint16,
	r io.Reader,
) (Round1SecretPackage, Round1Package, error) {

	if err := validateNumOfSigners(minSigners, maxSigners); err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	// refreshing_key with scalar = 0
	refreshingKey := modNZero()
	// t-1 random coeffs (a_{i1},...,a_{i,t-1})
	coeffOnly, err := generateCoefficients(int(minSigners) - 1)
	if err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	// Build polynomial with c0 = 0 and commitments φ_k = g^{a_{ik}}
	coeffs, commitment, err := generateSecretPolynomial(&refreshingKey, maxSigners, minSigners, coeffOnly)
	if err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	// Remove identity commitment (g^0) from the package commitment vector
	if len(commitment) == 0 {
		return Round1SecretPackage{}, Round1Package{}, ErrInvalidCommitVector
	}
	trimmed := make([]CoefficientCommitment, len(commitment)-1)
	copy(trimmed, commitment[1:])
	trimCommit := VerifiableSecretSharingCommitment{trimmed}

	verifyingKey, err := trimCommit.ToVerifyingKey()
	if err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	// Proof of knowledge over the trimmed commitment (we don't verify it later)
	sig, err := computeProofOfKnowledge(identifier, coeffs, verifyingKey, r)
	if err != nil {
		return Round1SecretPackage{}, Round1Package{}, err
	}

	sec := Round1SecretPackage{
		Identifier:   identifier,
		Coefficients: coeffs,     // includes c0 = 0
		Commitment:   trimCommit, // identity removed publicly
		MinSigners:   minSigners,
		MaxSigners:   maxSigners,
	}
	pub := Round1Package{
		Commitment:       trimCommit,
		ProofOfKnowledge: sig,
	}
	return sec, pub, nil
}

// -----------------------------------------------------------------------------
// Refresh DKG - Part 2
// -----------------------------------------------------------------------------

// DKGRefreshPart2 adds the identity commitment back to the local secret package,
// prepares Round 2 packages (shares) for peers, and returns the Round 2 secret.
func DKGRefreshPart2(
	secretPkg Round1SecretPackage,
	round1Pkgs map[Identifier]Round1Package,
) (Round2SecretPackage, map[Identifier]Round2Package, error) {

	if len(round1Pkgs) != int(secretPkg.MaxSigners-1) {
		return Round2SecretPackage{}, nil, ErrIncorrectNumberOfPackages
	}

	// Rebuild my commitment with the identity element re-inserted at the front.
	// identity = g^0 (point at infinity)
	elemIdentity := secp.JacobianPoint{}

	identity := CoefficientCommitment(elemIdentity)
	myCoeffs := make([]CoefficientCommitment, 0, 1+len(secretPkg.Commitment.Coeffs))
	myCoeffs = append(myCoeffs, identity)
	myCoeffs = append(myCoeffs, secretPkg.Commitment.Coeffs...)
	secretPkg.Commitment = VerifiableSecretSharingCommitment{myCoeffs}

	out := make(map[Identifier]Round2Package, len(round1Pkgs))

	for senderID, r1 := range round1Pkgs {
		// For each peer's Round1 package, also add identity back
		peerCoeffs := make([]CoefficientCommitment, 0, 1+len(r1.Commitment.Coeffs))
		peerCoeffs = append(peerCoeffs, identity)
		peerCoeffs = append(peerCoeffs, r1.Commitment.Coeffs...)

		if len(peerCoeffs) != int(secretPkg.MinSigners) {
			return Round2SecretPackage{}, nil, ErrIncorrectNumberOfCommitments
		}

		// Compute my share intended for `senderID`: f_i(senderID)
		share := secretShareFromCoefficients(secretPkg.Coefficients, senderID)

		out[senderID] = Round2Package{
			SecretShare: share,
		}
	}

	// Keep f_i(i)
	fii := evaluatePolynomial(secretPkg.Identifier, secretPkg.Coefficients)

	return Round2SecretPackage{
		Identifier:  secretPkg.Identifier,
		Commitment:  secretPkg.Commitment,
		SecretShare: fii,
		MinSigners:  secretPkg.MinSigners,
		MaxSigners:  secretPkg.MaxSigners,
	}, out, nil
}

// DKGRefreshShares verifies incoming Round2 shares against Round1 commitments
// (with identity re-added), adds them all up with f_i(i), then *adds* the old
// long-lived share, producing refreshed KeyPackage and PublicKeyPackage.
//
// The joint public key stays the same; verifying shares are updated by adding
// the “zero-shares” public contributions to the old ones.
func DKGRefreshPart3(
	r2Secret *Round2SecretPackage,
	round1Pkgs map[Identifier]Round1Package,
	round2Pkgs map[Identifier]Round2Package,
	oldPKP PublicKeyPackage,
	oldKP KeyPackage,
) (KeyPackage, PublicKeyPackage, error) {

	// Rebuild Round1 packages with identity commitment added back in.
	newR1 := make(map[Identifier]Round1Package, len(round1Pkgs))

	elemIdentity := secp.JacobianPoint{}
	identity := CoefficientCommitment(elemIdentity)

	for senderID, r1 := range round1Pkgs {
		coeffs := make([]CoefficientCommitment, 0, 1+len(r1.Commitment.Coeffs))
		coeffs = append(coeffs, identity)
		coeffs = append(coeffs, r1.Commitment.Coeffs...)

		newR1[senderID] = Round1Package{
			Commitment:       VerifiableSecretSharingCommitment{coeffs},
			ProofOfKnowledge: r1.ProofOfKnowledge,
		}
	}

	if len(newR1) != int(r2Secret.MaxSigners-1) {
		return KeyPackage{}, PublicKeyPackage{}, ErrIncorrectNumberOfPackages
	}
	if len(newR1) != len(round2Pkgs) {
		return KeyPackage{}, PublicKeyPackage{}, ErrIncorrectNumberOfPackages
	}
	for id := range newR1 {
		if _, ok := round2Pkgs[id]; !ok {
			return KeyPackage{}, PublicKeyPackage{}, ErrIncorrectPackage
		}
	}

	// s_i = sum_{ℓ} f_ℓ(i) + f_i(i) + old_s_i
	si := modNZero()

	for senderID, r2 := range round2Pkgs {
		// Verify g^{f_ℓ(i)} ?= Σ φ_{ℓk} i^k using the rebuilt Round1 commitment.
		r1 := newR1[senderID]
		temp := ThresholdShare{
			Identifier: r2Secret.Identifier,
			SecretSh:   r2.SecretShare,
			Commitment: r1.Commitment,
		}
		if _, _, err := temp.Verify(); err != nil {
			return KeyPackage{}, PublicKeyPackage{}, err
		}
		si.Add((*secp.ModNScalar)(&r2.SecretShare))
	}

	// Add my f_i(i)
	si.Add(&r2Secret.SecretShare)

	// Add previous long-lived share
	oldShare := oldKP.SecretShare
	si.Add((*secp.ModNScalar)(&oldShare))

	newSecretShare := SecretShare(si)
	newVerifying := elemBaseMul((*secp.ModNScalar)(&newSecretShare))

	// Build zero-shares PublicKeyPackage from rebuilt commitments (peers + mine)
	commitMap := make(map[Identifier]*VerifiableSecretSharingCommitment, len(newR1)+1)
	for id, p := range newR1 {
		c := p.Commitment
		commitMap[id] = &c
	}
	commitMap[r2Secret.Identifier] = &r2Secret.Commitment

	zeroPKP, err := PKPFromDKGCommitments(commitMap)
	if err != nil {
		return KeyPackage{}, PublicKeyPackage{}, err
	}

	// New verifying shares = zeroPKP share + oldPKP share (group key unchanged)
	newVS := make(map[Identifier]VerifyingShare, len(zeroPKP.VerifyingShares))
	for id, vsNew := range zeroPKP.VerifyingShares {
		vsOld, ok := oldPKP.VerifyingShares[id]
		if !ok {
			return KeyPackage{}, PublicKeyPackage{}, ErrUnknownIdentifier
		}
		sum := elemAdd(vsNew, vsOld)
		newVS[id] = VerifyingShare(sum)
	}

	pub := PublicKeyPackage{
		VerifyingShares: newVS,
		VerifyingKey:    oldPKP.VerifyingKey, // unchanged
	}

	kp := KeyPackage{
		r2Secret.Identifier,
		newSecretShare,
		newVerifying,
		pub.VerifyingKey,
		r2Secret.MinSigners,
	}

	return kp, pub, nil
}

func validateNumOfSigners(minSigners, maxSigners uint16) error {
	if minSigners < 2 {
		return ErrInvalidMinSigners
	}
	if maxSigners < 2 {
		return ErrInvalidMaxSigners
	}
	if minSigners > maxSigners {
		return ErrInvalidMinSigners
	}
	return nil
}

func NewSecretKey(r io.Reader) (*SecretKey, error) {
	var s secp.ModNScalar
	for {
		var b [32]byte
		if _, err := r.Read(b[:]); err != nil {
			return nil, err
		}
		_ = s.SetByteSlice(b[:])
		if !s.IsZero() {
			break
		}
	}
	return &SecretKey{Scalar: s}, nil
}

type SecretKey struct {
	Scalar secp.ModNScalar
}
