package threshold_signing

import (
	"crypto/sha256"

	"github.com/decred/dcrd/dcrec/secp256k1/v4"
)

// / [spec]: https://www.ietf.org/archive/id/draft-irtf-cfrg-frost-14.html#section-6.5-1
const CONTEXT_STRING = "FROST-secp256k1-SHA256-TR-v1"

func hashToArray(input [][]byte) [32]byte {
	hasher := sha256.New()

	for _, data := range input {
		hasher.Write(data)
	}

	var arr [32]byte
	copy(arr[:], hasher.Sum(nil))
	return arr

}

func hashToScalar(input [][]byte) secp256k1.ModNScalar {
	scalar := secp256k1.ModNScalar{}
	array := hashToArray(input)
	scalar.SetBytes(&array)
	return scalar
}

func H1(input []byte) secp256k1.ModNScalar {
	prefix := []byte("rho")
	context_bytes := []byte(CONTEXT_STRING)

	return hashToScalar([][]byte{context_bytes, prefix, input})
}

func H2(input []byte) secp256k1.ModNScalar {
	prefix := []byte("BIP0340/challenge")
	context_bytes := []byte(CONTEXT_STRING)

	return hashToScalar([][]byte{context_bytes, prefix, input})
}

func H3(input []byte) secp256k1.ModNScalar {
	prefix := []byte("nonce")
	context_bytes := []byte(CONTEXT_STRING)

	return hashToScalar([][]byte{context_bytes, prefix, input})
}

func H4(input []byte) []byte {
	prefix := []byte("msg")
	context_bytes := []byte(CONTEXT_STRING)

	arr := hashToArray([][]byte{context_bytes, prefix, input})
	return arr[:]
}

func H5(input []byte) []byte {
	prefix := []byte("com")
	context_bytes := []byte(CONTEXT_STRING)

	arr := hashToArray([][]byte{context_bytes, prefix, input})
	return arr[:]
}

func HDKG(input []byte) secp256k1.ModNScalar {
	prefix := []byte("dkg")
	context_bytes := []byte(CONTEXT_STRING)

	return hashToScalar([][]byte{context_bytes, prefix, input})
}

func HID(input []byte) secp256k1.ModNScalar {
	prefix := []byte("id")
	context_bytes := []byte(CONTEXT_STRING)

	return hashToScalar([][]byte{context_bytes, prefix, input})
}
