// Command demo_profile installs the generated shareware presentation extension.
package main

import (
	"flag"
	"log"

	"github.com/gravestench/dark-magic/internal/content"
	"github.com/gravestench/dark-magic/internal/modcache"
)

func main() {
	source := flag.String("source", "", "generated demo-profile directory")
	flag.Parse()
	if *source == "" {
		log.Fatal("-source is required")
	}
	paths, err := modcache.DefaultPaths()
	if err != nil {
		log.Fatal(err)
	}
	store, err := modcache.New(paths.Cache)
	if err != nil {
		log.Fatal(err)
	}
	if _, err := store.ReconcileBundled([]modcache.Bundle{{Source: content.Directory(*source)}}); err != nil {
		log.Fatal(err)
	}
}
