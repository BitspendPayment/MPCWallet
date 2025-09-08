package thresholdnostrdkg

import (
	"github.com/nbd-wtf/go-nostr"
)

func containsAll(tags nostr.Tags, kv map[string]string) bool {
	for k, v := range kv {
		if !tags.ContainsAny(k, []string{v}) {
			return false
		}
	}
	return true
}
