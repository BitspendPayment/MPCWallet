package thresholdnostrdkg

import (
	"context"
	"crypto/rand"
	"fmt"
	"log"
	"testing"
	"time"
)

// Helper to generate a random 32-byte secret key
func generateSecretKey() ([]byte, error) {
	key := make([]byte, 32)
	_, err := rand.Read(key)
	if err != nil {
		return nil, err
	}
	return key, nil
}

// Helper to create and wire up three DKGParticipants
func CreateAndWireThreeParticipants(relayUrl string, min, max uint16) ([]*DKGParticipant, error) {
	var participants []*DKGParticipant
	var pubkeys []string

	// Step 1: Generate secret keys and create participants
	for i := 0; i < int(max); i++ {
		secretKey, err := generateSecretKey()
		if err != nil {
			return nil, fmt.Errorf("failed to generate secret key: %w", err)
		}
		p, err := NewDKGParticipant(secretKey, relayUrl, min, max)
		if err != nil {
			return nil, fmt.Errorf("failed to create participant: %w", err)
		}
		participants = append(participants, &p)
		pubkeys = append(pubkeys, p.nostrPackage.PublicKey)
	}

	// Step 2: Register all pubkeys with each participant
	for _, p := range participants {
		for _, pk := range pubkeys {
			if pk != p.nostrPackage.PublicKey {
				_ = p.AddDKGParticipant(pk)
			}
		}
	}

	return participants, nil
}

// Example usage
func TestNostrDkg(t *testing.T) {
	min, max := uint16(5), uint16(12)

	c, relayUrl := CreateNostrContainer(t)
	defer c.Terminate(context.Background())

	println("Container ID:", c.GetContainerID())
	participants, err := CreateAndWireThreeParticipants(relayUrl, min, max)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}

	participantsPublicKeys := make([]string, len(participants))
	for i, p := range participants {
		participantsPublicKeys[i] = p.nostrPackage.PublicKey
	}

	if err != nil {
		log.Fatalf("Failed to initiate DKG: %v", err)
	}

	for _, p := range participants {
		p.StartHandlingDKGMessages()
	}

	// Start DKG
	initiator := participants[0]
	err = initiator.IniatiateNostrDKG()

	if err != nil {
		log.Fatalf("Failed to initiate DKG: %v", err)
	}

	// Wait
	for {
		println("Waiting for DKG to complete...")
		time.Sleep(5 * time.Second)
	}

}
