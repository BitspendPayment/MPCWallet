package thresholdcore

import (
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
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
		tmp := modNDouble(&sum) // sum = sum + sum
		sum = tmp
		if (n & (1 << uint(i))) != 0 {
			sum = modNAdd(&sum, &one) // sum += 1
		}
	}
	return sum, nil
}

func (i *Identifier) UnmarshalJSON(b []byte) error {
	var id uint16
	if err := json.Unmarshal(b, &id); err != nil {
		return err
	}

	parsedId, err := FromUint16(id)
	if err != nil {
		return err
	}

	i.s = parsedId

	return nil
}

func (s *SecretKey) UnmarshalJSON(b []byte) error {
	var hexStr string
	if err := json.Unmarshal(b, &hexStr); err != nil {
		return err
	}
	raw, err := hex.DecodeString(hexStr)
	if err != nil {
		return fmt.Errorf("scalar hex: %w", err)
	}
	var tmp secp.ModNScalar
	overflow := tmp.SetByteSlice(raw) // returns true if >= N
	if overflow {
		return errors.New("scalar not in field (overflow)")
	}
	s.Scalar = tmp
	return nil

}

func (s *SecretShare) UnmarshalJSON(b []byte) error {
	var hexStr string
	if err := json.Unmarshal(b, &hexStr); err != nil {
		return err
	}
	raw, err := hex.DecodeString(hexStr)
	if err != nil {
		return fmt.Errorf("scalar hex: %w", err)
	}
	var tmp secp.ModNScalar
	overflow := tmp.SetByteSlice(raw) // returns true if >= N
	if overflow {
		return errors.New("scalar not in field (overflow)")
	}
	s.s = tmp
	return nil
}

func (vs *VerifyingShare) UnmarshalJSON(b []byte) error {
	var hexStr string
	if err := json.Unmarshal(b, &hexStr); err != nil {
		return err
	}
	raw, err := hex.DecodeString(hexStr)
	if err != nil {
		return fmt.Errorf("element hex: %w", err)
	}
	e, err := elemDeserializeCompressed(raw)
	if err != nil {
		return fmt.Errorf("element deserialize: %w", err)
	}
	vs.E = e
	return nil
}

func (vss *VerifiableSecretSharingCommitment) UnmarshalJSON(b []byte) error {
	var hexStrs []string
	if err := json.Unmarshal(b, &hexStrs); err != nil {
		return err
	}
	coeffs := make([]CoefficientCommitment, 0, len(hexStrs))
	for i, hs := range hexStrs {
		raw, err := hex.DecodeString(hs)
		if err != nil {
			return fmt.Errorf("element %d hex: %w", i, err)
		}
		var cc CoefficientCommitment
		if err := cc.Deserialize(raw); err != nil {
			return fmt.Errorf("element %d deserialize: %w", i, err)
		}
		coeffs = append(coeffs, cc)
	}
	vss.Coeffs = coeffs
	return nil
}

func (vk *VerifyingKey) UnmarshalJSON(b []byte) error {
	var hexStr string
	if err := json.Unmarshal(b, &hexStr); err != nil {
		return err
	}
	raw, err := hex.DecodeString(hexStr)
	if err != nil {
		return fmt.Errorf("element hex: %w", err)
	}
	e, err := elemDeserializeCompressed(raw)
	if err != nil {
		return fmt.Errorf("element deserialize: %w", err)
	}
	vk.E = e
	return nil
}
