package thresholdcore

import (
	"crypto/rand"
	"io"

	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
)

func modNFromBytesBE(b []byte) (secp.ModNScalar, error) {
	var s secp.ModNScalar
	// SetByteSlice reduces mod N and reports overflow (value >= N) via the bool.
	// We accept overflow since reduction is the desired behavior.
	_ = s.SetByteSlice(b)
	if s.IsZero() {
		return s, ErrInvalidZeroScalar
	}
	return s, nil
}

func modNZero() secp.ModNScalar {
	var z secp.ModNScalar
	// zero value is 0
	return z
}

func modNOne() secp.ModNScalar {
	var one secp.ModNScalar
	one.SetInt(1)
	return one
}

// Serialize compressed: Jacobian -> affine -> compressed pubkey
func elemSerializeCompressed(e secp.JacobianPoint) ([]byte, error) {
	var ax, ay secp.FieldVal
	ax.Set(&e.X)
	ay.Set(&e.Y)

	// Convert to affine if needed
	aff := e
	aff.ToAffine()

	// Build a PublicKey from affine X,Y (FieldVal → big.Int)
	x := aff.X
	y := aff.Y
	pk := secp.NewPublicKey(&x, &y)
	return pk.SerializeCompressed(), nil
}

// Deserialize compressed: pubkey(compressed) -> affine -> Jacobian(Z=1)
func elemDeserializeCompressed(b []byte) (secp.JacobianPoint, error) {
	pk, err := secp.ParsePubKey(b)
	if err != nil {
		return secp.JacobianPoint{}, err
	}
	// Fill a Jacobian with Z=1 from affine X,Y.
	var j secp.JacobianPoint

	pk.AsJacobian(&j)

	return j, nil
}

// Base * scalar
func elemBaseMul(k *secp.ModNScalar) secp.JacobianPoint {
	// Adjust name if your local API differs (e.g., ScalarBaseMultNonConst)
	var r secp.JacobianPoint
	secp.ScalarBaseMultNonConst(k, &r)
	return r
}

// P + Q
func elemAdd(a, b secp.JacobianPoint) secp.JacobianPoint {
	var r secp.JacobianPoint
	secp.AddNonConst(&a, &b, &r)
	return r
}

// P * k
func elemMul(a secp.JacobianPoint, k *secp.ModNScalar) secp.JacobianPoint {
	// Adjust name if your local API differs (e.g., ScalarMultNonConst)
	var r secp.JacobianPoint
	secp.ScalarMultNonConst(k, &a, &r)
	return r
}

// Random non-zero scalar
func modNRandom() (secp.ModNScalar, error) {
	for {
		var b [32]byte
		if _, err := rand.Read(b[:]); err != nil {
			return modNZero(), err
		}
		var s secp.ModNScalar
		_ = s.SetByteSlice(b[:])
		if !s.IsZero() {
			return s, nil
		}
	}
}

// poly evaluate at x = identifier (Horner), coefficients[0] is constant term
func evaluatePolynomial(id Identifier, coeffs []secp.ModNScalar) secp.ModNScalar {
	if len(coeffs) == 0 {
		return modNZero()
	}
	x := id.ToScalar()
	val := modNZero()
	// value = ((...(c_{t-1} * x + c_{t-2}) * x + ... ) * x ) + c0
	for i := len(coeffs) - 1; i >= 0; i-- {
		if i != len(coeffs)-1 {
			val.Mul(&x)
		}
		val.Add(&coeffs[i])
	}
	return val
}

func generateCoefficients(size int) ([]secp.ModNScalar, error) {
	out := make([]secp.ModNScalar, size)
	for i := 0; i < size; i++ {
		s, err := modNRandom()
		if err != nil {
			return nil, err
		}
		out[i] = s
	}
	return out, nil
}

func GenerateCoefficients(minSigners uint16) ([]secp.ModNScalar, error) {
	size := int(minSigners) - 1
	return generateCoefficients(size)
}

// ===========================================================
// Lagrange reconstruction at x=0
// ===========================================================

// λ_i(0) = ∏_{j∈S, j≠i} (-j)/(i-j)  over the field (mod n)
func lagrangeCoeffAtZero(i Identifier, set []Identifier) *secp.ModNScalar {
	num := modNOne()
	den := modNOne()

	for _, j := range set {
		ii := i.ToScalar()

		if j.Equal(i) {
			continue
		}

		jj := j.ToScalar()

		negj := jj.Negate() // -j
		num.Mul(negj)

		//(i - j)
		den.Mul(ii.Add(negj))
	}

	denInv := den.InverseNonConst()
	return num.Mul(denInv)
}

// Map hash -> ModNScalar allowing zero (unlike modNFromBytesBE which rejects zero).
func modNFromBytesAllowZero(b []byte) secp.ModNScalar {
	var s secp.ModNScalar
	_ = s.SetByteSlice(b) // reduces mod n
	return s
}

// generator^k with fresh random non-zero k.
func generateNonce(r io.Reader) (secp.ModNScalar, secp.JacobianPoint, error) {
	// k
	var k secp.ModNScalar
	for {
		var b [32]byte
		if _, err := r.Read(b[:]); err != nil {
			return modNZero(), secp.JacobianPoint{}, err
		}
		_ = k.SetByteSlice(b[:])
		if !k.IsZero() {
			break
		}
	}
	// R = g^k
	R := elemBaseMul(&k)
	return k, R, nil
}

// Generate polynomial (+commitments) with secret as c0
func generateSecretPolynomial(
	secret *secp.ModNScalar,
	maxSigners, minSigners uint16,
	coeffOnly []secp.ModNScalar,
) ([]secp.ModNScalar, []secp.JacobianPoint, error) {

	if err := validateNumOfSigners(minSigners, maxSigners); err != nil {
		return nil, nil, err
	}
	if len(coeffOnly) != int(minSigners)-1 {
		return nil, nil, ErrInvalidCoefficients
	}

	coeffs := make([]secp.ModNScalar, 0, len(coeffOnly)+1)
	coeffs = append(coeffs, *secret) // c0 = secret
	coeffs = append(coeffs, coeffOnly...)

	commit := make([]CoefficientCommitment, len(coeffs))
	for i := range coeffs {
		commit[i] = elemBaseMul(&coeffs[i])
	}
	return coeffs, commit, nil
}

// φ_{i0} is the first coefficient commitment → verifying key
// σ = (R, z) with R = g^k, z = k + a_{i0} * c, c = challenge(i, φ_{i0}, R)
func computeProofOfKnowledge(
	identifier Identifier,
	coefficients []secp.ModNScalar,
	verifyingKey VerifyingKey,
	r io.Reader,
) (Signature, error) {

	// k, R = g^k
	k, R, err := generateNonce(r)
	if err != nil {
		return Signature{}, err
	}

	// c = H(i, φ_{i0}, R)
	chal, err := dkgChallenge(identifier, verifyingKey, R)
	if err != nil {
		return Signature{}, err
	}
	// a_{i0}
	if len(coefficients) == 0 {
		return Signature{}, ErrInvalidCoefficients
	}
	a0 := coefficients[0]

	// z = k + a0 * c
	zc := a0.Mul(&chal.C)
	z := zc.Add(&k)

	return Signature{R: R, Z: *z}, nil
}

// Verify σℓ = (Rℓ, μℓ): check Rℓ ?= g^{μℓ} · φ_{ℓ0}^{-cℓ}
func verifyProofOfKnowledge(
	identifier Identifier, // ℓ
	verifyingKey VerifyingKey,
	sig *Signature,
) error {

	// cℓ = H(ℓ, φ_{ℓ0}, Rℓ)
	chal, err := dkgChallenge(identifier, verifyingKey, sig.R)
	if err != nil {
		return err
	}

	// right = g^{μℓ} + (φ_{ℓ0} * (-cℓ))
	left := sig.R
	mu := sig.Z

	gmu := elemBaseMul(&mu)
	cneg := chal.C
	cneg.Negate()

	phiNeg := elemMul(verifyingKey.E, &cneg)
	right := elemAdd(gmu, phiNeg)

	eq := left.EquivalentNonConst(&right)

	if !eq {
		return ErrInvalidSecretShare // reusing; or define ErrInvalidProofOfKnowledge
	}
	return nil
}
