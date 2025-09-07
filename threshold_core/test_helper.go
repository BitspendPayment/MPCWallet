package thresholdcore

import (
	"math/bits"

	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
)

// FromUint16 creates an Identifier from a non-zero u16 using left-to-right
// double-and-add in the scalar field (mirrors the Rust bit-walk).
func FromUint16(n uint16) (secp.ModNScalar, error) {
	if n == 0 {
		return secp.ModNScalar{}, ErrInvalidZeroScalar
	}
	one := modNOne()
	sum := modNOne()

	totalBits := uint(16)
	lz := uint(bits.LeadingZeros16(n))
	for i := int(totalBits - lz - 1); i >= 0; i-- {
		sum.Add(&sum) // sum = sum + sum
		if (n & (1 << uint(i))) != 0 {
			sum.Add(&one) // sum += 1
		}
	}
	return sum, nil
}

func IdentifierFromUint16(n uint16) (Identifier, error) {
	s, err := FromUint16(n)
	if err != nil {
		return Identifier{}, err
	}
	return Identifier{s}, nil
}

func defaultIdentifiers(maxSigners uint16) ([]Identifier, error) {
	out := make([]Identifier, 0, maxSigners)
	for i := uint16(1); i <= maxSigners; i++ {
		id, err := FromUint16(i)
		if err != nil {
			return nil, err
		}
		out = append(out, Identifier{id})
	}
	return out, nil
}
