package thresholdcore

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"hash/fnv"

	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
)

// Errors aligned with the Rust version.
var (
	ErrIdentifierDerivationNotSupported = errors.New("identifier derivation not supported")
)

// Identifier is a FROST participant identifier over secp256k1 (mod N).
// It must never be zero (since f(0) = secret).
type Identifier struct {
	S secp.ModNScalar // value type from decred; holds scalar mod curve order
}

// --- API ---

// NewIdentifier constructs an Identifier from a (non-zero) scalar.
func NewIdentifier(s secp.ModNScalar) (Identifier, error) {
	if s.IsZero() {
		return Identifier{}, ErrInvalidZeroScalar
	}
	return Identifier{S: s}, nil
}

// ToScalar returns a copy of the inner scalar.
func (id Identifier) ToScalar() secp.ModNScalar { return id.S }

// Derive hashes arbitrary bytes into a scalar identifier (rejects zero).
// If you need a domain-separated variant, prefix or tag the input before calling.
func Derive(msg []byte) (Identifier, error) {
	// Simple HID: hash → mod-N scalar
	h := sha256.Sum256(msg)
	s, err := modNFromBytesBE(h[:])
	if err != nil {
		return Identifier{}, err
	}
	return NewIdentifier(s)
}

// Serialize returns the 32-byte big-endian encoding of the scalar (Decred’s encoding).
func (id Identifier) Serialize() []byte {
	be := id.S.Bytes() // [32]byte big-endian
	return be[:]
}

// DeserializeIdentifier parses a 32-byte big-endian scalar and rejects zero.
func DeserializeIdentifier(b []byte) (Identifier, error) {
	s, err := modNFromBytesBE(b)
	if err != nil {
		return Identifier{}, err
	}
	return NewIdentifier(s)
}

// String provides a Debug-like view: Identifier(<hex>).
func (id Identifier) String() string {
	return fmt.Sprintf("Identifier(%s)", hex.EncodeToString(id.Serialize()))
}

// Equal compares identifiers by their canonical serialization.
func (id Identifier) Equal(other Identifier) bool {
	a := id.Serialize()
	b := other.Serialize()
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// Hash returns a stable 64-bit hash over the serialized scalar (FNV-1a).
func (id Identifier) Hash() uint64 {
	h := fnv.New64a()
	_, _ = h.Write(id.Serialize())
	return h.Sum64()
}

// Compare provides a total ordering consistent with Rust's Ord impl.
// It compares the big-endian byte representation lexicographically.
func (id Identifier) Compare(other Identifier) int {
	a := id.Serialize()
	b := other.Serialize()

	// If lengths differ (they won't here), left-pad the shorter with zeros.
	// Since both are 32 bytes, just compare lexicographically.
	for i := 0; i < len(a) && i < len(b); i++ {
		if a[i] < b[i] {
			return -1
		}
		if a[i] > b[i] {
			return 1
		}
	}
	// If equal length and all bytes equal, they are equal.
	if len(a) == len(b) {
		return 0
	}
	if len(a) < len(b) {
		return -1
	}
	return 1
}

// Less is handy for sort.Interface.
func (id Identifier) Less(other Identifier) bool { return id.Compare(other) < 0 }
