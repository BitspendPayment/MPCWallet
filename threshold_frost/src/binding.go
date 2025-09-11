package threshold_signing

import (
	thres "github.com/ArkLabsHQ/thresholdmagic/thresholdcore"
	"github.com/decred/dcrd/dcrec/secp256k1/v4"
)

type BindingFactor struct {
	Scalar secp256k1.ModNScalar
}

type BindingFactorList struct {
	F map[thres.Identifier]BindingFactor
}

func (b *BindingFactorList) Get(id thres.Identifier) (*BindingFactor, bool) {
	v, ok := b.F[id]
	if !ok {
		return nil, false
	}
	return &v, true
}

type BindingFactorPreimage struct {
	ID       thres.Identifier
	Preimage []byte
}

func ComputeBindingFactorList(
	s *SigningPackage,
	vk thres.VerifyingKey,

) (BindingFactorList, error) {
	preimages, err := s.bindingFactorPreimages(vk)
	if err != nil {
		return BindingFactorList{}, err
	}

	out := make(map[thres.Identifier]BindingFactor, len(preimages))
	for _, p := range preimages {
		bf := BindingFactor{
			Scalar: H1(p.Preimage),
		}
		out[p.ID] = bf
	}

	return BindingFactorList{F: out}, nil
}
