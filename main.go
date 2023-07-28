package main

import (
	"github.com/bensolo-io/aws-global-elasticache-promoter/cmd"
	"github.com/rs/zerolog"
)

func init() {
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	zerolog.SetGlobalLevel(zerolog.DebugLevel)
}

func main() {
	cmd.Execute()
}
