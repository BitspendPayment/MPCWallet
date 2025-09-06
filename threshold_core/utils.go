package thresholdcore

import (
	"crypto/rand"
	"io"
	"math/big"

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

var secpN = new(big.Int).SetBytes([]byte{
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFE, 0xBA, 0xAE, 0xDC,
	0xE6, 0xAF, 0x48, 0xA0, 0x3B, 0xBF, 0xD2, 0x5E,
	0x8C, 0xD0, 0x36, 0x41, 0x41,
})

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

func modNMul(a, b *secp.ModNScalar) secp.ModNScalar {
	var out secp.ModNScalar
	out.Mul2(a, b)
	return out
}

func modNAdd(a, b *secp.ModNScalar) secp.ModNScalar {
	var out secp.ModNScalar
	out.Add2(a, b) // out = a + b (mod N)
	return out
}

func modNDouble(a *secp.ModNScalar) secp.ModNScalar {
	// 2a = a + a
	return modNAdd(a, a)
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
			val = modNMul(&val, &x)
		}
		val = modNAdd(&val, &coeffs[i])
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

// RHS of VSS verification: sum_k φ_k * (i^k)
func evaluateVSS(id Identifier, commit *VerifiableSecretSharingCommitment) secp.JacobianPoint {
	x := id.ToScalar()
	// i^0 = 1
	itok := modNOne()
	sum := secp.JacobianPoint{}
	for k := 0; k < len(commit.Coeffs); k++ {
		term := elemMul(commit.Coeffs[k].E, &itok)
		sum = elemAdd(sum, term)
		// next power
		itok = modNMul(&itok, &x)
	}
	return sum
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
