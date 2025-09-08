package thresholdnostrdkg

import (
	"context"
	"fmt"
	"testing"

	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
)

func CreateNostrContainer(t *testing.T) (testcontainers.Container, string) {
	ctx := context.Background()

	req := testcontainers.ContainerRequest{
		Image:        "scsibug/nostr-rs-relay:latest",
		ExposedPorts: []string{"8080/tcp"},
		Env: map[string]string{
			"RELAY_PORT": "8080",
			"RELAY_HOST": "0.0.0.0",
		},
		WaitingFor: wait.ForLog("listening on"),
	}

	relayC, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: req,
		Started:          true,
	})
	if err != nil {
		t.Fatalf("failed to start relay: %v", err)
	}

	host, err := relayC.Host(ctx)
	if err != nil {
		t.Fatal(err)
	}
	port, err := relayC.MappedPort(ctx, "8080")
	if err != nil {
		t.Fatal(err)
	}

	relayURL := fmt.Sprintf("ws://%s:%s", host, port.Port())
	t.Log("Relay running at:", relayURL)

	return relayC, relayURL
}
