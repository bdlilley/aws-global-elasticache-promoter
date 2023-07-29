package cmd

import (
	"fmt"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/bensolo-io/aws-global-elasticache-promoter/pkg/awslambda"
	"github.com/bensolo-io/aws-global-elasticache-promoter/pkg/config"
	"github.com/rs/zerolog/log"
	"github.com/spf13/cobra"
)

var cfg config.Config = config.Config{}

var rootCmd = &cobra.Command{
	Use:   "redis-promoter",
	Short: "redis-promoter - detects regional dns failover and promotes secondary redis instances to primary",
	PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
		if cfg.HostedZoneID == "" {
			cfg.HostedZoneID = os.Getenv("HOSTED_ZONE_ID")
			if cfg.HostedZoneID == "" {
				log.Fatal().Msg("HOSTED_ZONE_ID or --hz is required")
			}
		}
		if cfg.DnsName == "" {
			cfg.DnsName = os.Getenv("DNS_NAME")
			if cfg.DnsName == "" {
				log.Fatal().Msg("DNS_NAME or --dns-name is required")
			}
		}
		if cfg.GlobalDataStoreId == "" {
			cfg.GlobalDataStoreId = os.Getenv("GLOBAL_DATASTORE_ID")
			if cfg.GlobalDataStoreId == "" {
				log.Fatal().Msg("GLOBAL_DATASTORE_ID or --global-data-store-id is required")
			}
		}
		cfg.DnsName = strings.TrimRight(cfg.DnsName, ".")

		return nil
	},
	RunE: func(cmd *cobra.Command, args []string) error {
		handler, err := awslambda.NewHandlerFunc(cfg)
		if err != nil {
			return err
		}

		if os.Getenv("AWS_LAMBDA_RUNTIME_API") != "" {
			log.Info().Msg("detected AWS lambda runtime, starting lambda handler")
			lambda.Start(handler)
			return nil
		}

		log.Info().Msg("no aws runtime detected, invoking handler directly")
		return handler(nil)
	},
}

func Execute() {
	rootCmd.PersistentFlags().StringVar(&cfg.HostedZoneID, "hz", "", "hosted zone id")
	rootCmd.PersistentFlags().StringVarP(&cfg.DnsName, "dns-name", "d", "", "dns name to watch for changes")
	rootCmd.PersistentFlags().StringVarP(&cfg.GlobalDataStoreId, "global-data-store-id", "g", "", "id of the elasticache global data store")

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Whoops. There was an error while executing your CLI '%s'", err)
		os.Exit(1)
	}
}
