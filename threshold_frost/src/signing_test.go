package threshold_signing

import (
	"crypto/rand"
	"testing"

	thres "github.com/ArkLabsHQ/thresholdmagic/thresholdcore"
	"github.com/decred/dcrd/dcrec/secp256k1/v4"
)

func randomScalar(t *testing.T) secp256k1.ModNScalar {
	t.Helper()

	var scalar secp256k1.ModNScalar
	for {
		var buf [32]byte
		if _, err := rand.Read(buf[:]); err != nil {
			t.Fatalf("failed to read randomness: %v", err)
		}
		_ = scalar.SetByteSlice(buf[:])
		if !scalar.IsZero() {
			return scalar
		}
	}
}

func runDealerDKG(t *testing.T, min, max uint16) ([]thres.KeyPackage, thres.PublicKeyPackage) {
	t.Helper()

	ids := make([]thres.Identifier, 0, max)
	for i := uint16(1); i <= max; i++ {
		id, err := thres.IdentifierFromUint16(i)
		if err != nil {
			t.Fatalf("IdentifierFromUint16(%d): %v", i, err)
		}
		ids = append(ids, id)
	}

	r1Secrets := make(map[thres.Identifier]thres.Round1SecretPackage, max)
	r1Pkgs := make(map[thres.Identifier]thres.Round1Package, max)

	for _, id := range ids {
		coeffs, err := thres.GenerateCoefficients(min)
		if err != nil {
			t.Fatalf("GenerateCoefficients: %v", err)
		}
		secPkg, pkg, err := thres.DKGPart1(id, max, min, thres.SecretKey{Scalar: randomScalar(t)}, coeffs, rand.Reader)
		if err != nil {
			t.Fatalf("DKGPart1(%v): %v", id, err)
		}
		r1Secrets[id] = secPkg
		r1Pkgs[id] = pkg
	}

	r2Secrets := make(map[thres.Identifier]thres.Round2SecretPackage, max)
	r2Outgoing := make(map[thres.Identifier]map[thres.Identifier]thres.Round2Package, max)

	for _, id := range ids {
		others := make(map[thres.Identifier]thres.Round1Package, max-1)
		for _, peer := range ids {
			if peer.Equal(id) {
				continue
			}
			others[peer] = r1Pkgs[peer]
		}
		secretPkg, outgoing, err := thres.DKGPart2(r1Secrets[id], others)
		if err != nil {
			t.Fatalf("DKGPart2(%v): %v", id, err)
		}
		r2Secrets[id] = secretPkg
		r2Outgoing[id] = outgoing
	}

	keyPackages := make([]thres.KeyPackage, 0, max)
	var pkp thres.PublicKeyPackage

	for _, id := range ids {
		inbound := make(map[thres.Identifier]thres.Round2Package, max-1)
		r1View := make(map[thres.Identifier]thres.Round1Package, max-1)
		for _, peer := range ids {
			if peer.Equal(id) {
				continue
			}
			inbound[peer] = r2Outgoing[peer][id]
			r1View[peer] = r1Pkgs[peer]
		}

		r1Secret := r1Secrets[id]
		r2Secret := r2Secrets[id]

		kp, pk, err := thres.DKGPart3(&r1Secret, &r2Secret, r1View, inbound)
		if err != nil {
			t.Fatalf("DKGPart3(%v): %v", id, err)
		}
		keyPackages = append(keyPackages, kp)
		if len(pkp.VerifyingShares) == 0 {
			pkp = pk
		}
	}

	return keyPackages, pkp
}

func TestSignAndAggregateEndToEnd(t *testing.T) {
	minSigners := uint16(2)
	maxSigners := uint16(3)

	keys, pkp := runDealerDKG(t, minSigners, maxSigners)

	signingPackage := SigningPackage{
		Commitments: make(map[thres.Identifier]SigningCommitments, minSigners),
		Message:     []byte("threshold frost end-to-end signature"),
	}

	nonces := make(map[thres.Identifier]SigningNonce, minSigners)
	signatureShares := make(map[thres.Identifier]SignatureShare, minSigners)

	// Build commitments from the first minSigners participants
	for i := 0; i < int(minSigners); i++ {
		kp := keys[i]
		nonce := NewNonce(kp.SecretShare, rand.Reader)
		nonces[kp.Identifier] = nonce
		signingPackage.Commitments[kp.Identifier] = nonce.commitments
	}

	for i := 0; i < int(minSigners); i++ {
		kp := keys[i]
		share, err := Sign(signingPackage, nonces[kp.Identifier], kp)
		if err != nil {
			t.Fatalf("Sign(%v): %v", kp.Identifier, err)
		}
		signatureShares[kp.Identifier] = *share
	}

	signature, err := Aggregate(&signingPackage, signatureShares, pkp)
	if err != nil {
		t.Fatalf("Aggregate: %v", err)
	}
	if signature == nil {
		t.Fatal("Aggregate returned nil signature without error")
	}

	challenge, err := ComputeChallenge(&signature.R, pkp.VerifyingKey, signingPackage.Message)
	if err != nil {
		t.Fatalf("ComputeChallenge: %v", err)
	}

	left := secp256k1.JacobianPoint{}
	secp256k1.ScalarBaseMultNonConst(&signature.Z, &left)

	eY := secp256k1.JacobianPoint{}
	secp256k1.ScalarMultNonConst(challenge, &pkp.VerifyingKey.E, &eY)

	right := secp256k1.JacobianPoint{}
	secp256k1.AddNonConst(&signature.R, &eY, &right)

	if !left.EquivalentNonConst(&right) {
		t.Fatal("aggregated signature did not verify against group key")
	}
}
