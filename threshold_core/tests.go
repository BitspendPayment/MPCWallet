package thresholdcore

import (
	"crypto/rand"
	"sort"
)

// DealerDKG is a quick path that runs a complete (non-interactive) flow
// for N participants locally (useful for tests).
func DealerDKG(n, t uint16) ([]KeyPackage, PublicKeyPackage, error) {
	if err := validateNumOfSigners(t, n); err != nil {
		return nil, PublicKeyPackage{}, err
	}
	ids, err := defaultIdentifiers(n)
	if err != nil {
		return nil, PublicKeyPackage{}, err
	}
	// Everyone runs part1
	r1Secrets := make(map[Identifier]Round1SecretPackage, n)
	r1Pkgs := make(map[Identifier]Round1Package, n)
	for _, id := range ids {
		sec, pkg, err := DKGPart1(id, n, t, rand.Reader)
		if err != nil {
			return nil, PublicKeyPackage{}, err
		}
		r1Secrets[id] = sec
		r1Pkgs[id] = pkg
	}
	// Everyone runs part2
	r2Secrets := make(map[Identifier]Round2SecretPackage, n)
	r2Outgoing := make(map[Identifier]map[Identifier]Round2Package, n)
	for _, id := range ids {
		// Build "others'" map for this participant
		others := make(map[Identifier]Round1Package, int(n-1))
		for _, j := range ids {
			if j.Equal(id) {
				continue
			}
			others[j] = r1Pkgs[j]
		}
		r2s, out, err := DKGPart2(r1Secrets[id], others)
		if err != nil {
			return nil, PublicKeyPackage{}, err
		}
		r2Secrets[id] = r2s
		r2Outgoing[id] = out
	}

	// Deliver round2 messages and run part3
	keys := make([]KeyPackage, 0, n)
	var pkp PublicKeyPackage

	for _, id := range ids {
		// Build inbound map for this participant
		inbound2 := make(map[Identifier]Round2Package, int(n-1))
		r1view := make(map[Identifier]Round1Package, int(n-1))
		for _, j := range ids {
			if j.Equal(id) {
				continue
			}
			inbound2[j] = r2Outgoing[j][id]
			r1view[j] = r1Pkgs[j]
		}
		kp, pk, err := DKGPart3(&r2Secrets[id], r1view, inbound2)
		if err != nil {
			return nil, PublicKeyPackage{}, err
		}
		keys = append(keys, kp)
		if len(pkp.VerifyingShares) == 0 {
			pkp = pk
		}
	}

	// Deterministic order
	sort.Slice(keys, func(i, j int) bool {
		return keys[i].Identifier.Less(keys[j].Identifier)
	})
	return keys, pkp, nil
}
