package threshold_signing

import "errors"

var (
	ErrIdentityCommitment              = errors.New("identity commitment")
	ErrUnknownIdentifier               = errors.New("unknown identifier")
	ErrIncorrectBindingFactorPreimages = errors.New("incorrect binding factor preimages")
	ErrInvalidCommitment               = errors.New("invalid commitment")
	ErrorWrongSignature                = errors.New("wrong signature")
	ErrorInvalidSignature              = errors.New("invalid signature")
)
