package thresholdcore

import "errors"

var (
	ErrInvalidZeroScalar          = errors.New("invalid zero scalar")
	ErrInvalidCoefficients        = errors.New("invalid coefficients")
	ErrInvalidMinSigners          = errors.New("invalid min_signers")
	ErrInvalidMaxSigners          = errors.New("invalid max_signers")
	ErrIncorrectNumberOfShares    = errors.New("incorrect number of shares")
	ErrIncorrectNumberOfIds       = errors.New("incorrect number of identifiers")
	ErrIncorrectNumberOfCommit    = errors.New("incorrect number of commitments")
	ErrDuplicatedIdentifier       = errors.New("duplicated identifier")
	ErrInvalidCoefficientEncoding = errors.New("invalid coefficient encoding")
	ErrInvalidSecretShare         = errors.New("invalid secret share")
	ErrInvalidCommitVector        = errors.New("invalid commitment vector size")
)
