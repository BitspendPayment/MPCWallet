package thresholdcore

import (
	"testing"

	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
	"github.com/stretchr/testify/assert"
)

func TestLagrangeCoeffAtZero_ReconstructsConstantTerm(t *testing.T) {
	// identifiers (distinct, non-zero)
	S, err := defaultIdentifiers(3)

	assert.NoError(t, err, "defaultIdentifiers")

	// Choose polynomial f(x) = a0 + a1 x + a2 x^2 (degree 2 < |S|)
	// You can pick any values < N; here we use small ints for readability.

	var a0, a1, a2 secp.ModNScalar
	a0.SetInt(12345) // the constant term we expect to recover
	a1.SetInt(6789)
	a2.SetInt(42)
	coeffs := []secp.ModNScalar{a0, a1, a2}

	// Compute shares y_i = f(i)
	type share struct {
		id Identifier
		y  secp.ModNScalar
	}
	var shares []share
	for _, id := range S {
		yi := evaluatePolynomial(id, coeffs)
		shares = append(shares, share{id: id, y: yi})
	}

	// Reconstruct f(0) using λ_i(0): sum λ_i(0) * y_i
	var recon secp.ModNScalar // starts at 0
	for _, sh := range shares {
		lambda := LagrangeCoeffAtZero(sh.id, S)
		var term secp.ModNScalar
		term.Set(&sh.y).Mul(lambda) // term = y_i * λ_i(0)
		recon.Add(&term)            // accumulate
	}

	if !recon.Equals(&a0) {
		t.Fatalf("reconstruction failed: got %v, want %v", recon, a0)
	}
}

func TestLagrangeCoeffAtZero_PermutationInvariant(t *testing.T) {
	id1, _ := IdentifierFromUint16(1)
	id2, _ := IdentifierFromUint16(2)
	id4, _ := IdentifierFromUint16(4)
	id7, _ := IdentifierFromUint16(7)

	S1 := []Identifier{id1, id2, id4, id7}
	S2 := []Identifier{id7, id4, id2, id1}

	for _, id := range S1 {
		l1 := LagrangeCoeffAtZero(id, S1)
		l2 := LagrangeCoeffAtZero(id, S2)
		if !l1.Equals(l2) {
			t.Fatalf("λ differs by permutation for id=%d", id)
		}
	}
}

func TestEvaluatePolynomial_EmptyCoeffs(t *testing.T) {
	id, _ := IdentifierFromUint16(123)

	got := evaluatePolynomial(id, nil)
	if !got.IsZero() {
		t.Fatalf("expected zero, got %x", got.Bytes())
	}
}

func TestEvaluatePolynomial_AgainstNaivePowerSum(t *testing.T) {
	id1, _ := IdentifierFromUint16(1)
	id2, _ := IdentifierFromUint16(2)
	id4, _ := IdentifierFromUint16(4)
	id7, _ := IdentifierFromUint16(7)
	id8, _ := IdentifierFromUint16(8)

	ids := []Identifier{id1, id2, id4, id7, id8}

	for degree := 1; degree <= 5; degree++ {
		coeffs := make([]secp.ModNScalar, degree+1)
		for i := range coeffs {
			coeffs[i], _ = modNRandom()
		}
		for _, id := range ids {
			got := evaluatePolynomial(id, coeffs)
			want := naiveEvaluatePolynomial(id, coeffs)

			if !got.Equals(&want) {
				t.Fatalf("degree=%d id=%d: naive mismatch:\n got  = %x\n want = %x",
					degree, id, got.Bytes(), want.Bytes())
			}
		}
	}
}

func TestEvaluatePolynomial_Constant(t *testing.T) {
	id, _ := IdentifierFromUint16(123)
	c0, _ := modNRandom()

	got := evaluatePolynomial(id, []secp.ModNScalar{c0})
	if !got.Equals(&c0) {
		t.Fatalf("constant poly mismatch: got %x want %x", got.Bytes(), c0.Bytes())
	}
}

// naive power-sum: sum_k coeff[k] * x^k (cross-checks Horner again)
func naiveEvaluatePolynomial(id Identifier, coeffs []secp.ModNScalar) secp.ModNScalar {
	if len(coeffs) == 0 {
		return modNZero()
	}
	x := id.ToScalar()
	pow := modNOne() // x^0
	sum := modNZero()
	for k := 0; k < len(coeffs); k++ {
		var term secp.ModNScalar
		term.Mul2(&coeffs[k], &pow) // coeff[k] * x^k

		var tmp secp.ModNScalar
		tmp.Add2(&sum, &term) // sum += term
		sum = tmp

		var nxt secp.ModNScalar
		nxt.Mul2(&pow, &x) // pow *= x
		pow = nxt
	}
	return sum
}
