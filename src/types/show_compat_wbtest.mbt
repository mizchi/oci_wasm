///|
// Expected output was captured from the previous derived Show implementations.
test "public Show formatting remains compatible" {
  inspect(
    Show::to_string(PackageName::{ ns: "example", name: "example", }),
    content="{ns: example, name: example}",
  )
  inspect(
    Show::to_string(AnyHash::{ algorithm: "example", hex: "example", }),
    content="{algorithm: example, hex: example}",
  )
  inspect(
    Show::to_string(OciConfig::{
      registry: "example",
      namespace_prefix: "example",
    }),
    content="{registry: example, namespace_prefix: example}",
  )
  inspect(
    Show::to_string(WargConfig::{ url: "example", }),
    content="{url: example}",
  )
  inspect(
    Show::to_string(
      RegistryBackend::Oci(OciConfig::{
        registry: "example",
        namespace_prefix: "example",
      }),
    ),
    content="Oci({registry: example, namespace_prefix: example})",
  )
  inspect(
    Show::to_string(RegistryBackend::Warg(WargConfig::{ url: "example", })),
    content="Warg({url: example})",
  )
  inspect(
    Show::to_string(RegistryConfig::{
      preferred: RegistryBackend::Oci(OciConfig::{
        registry: "example",
        namespace_prefix: "example",
      }),
      oci: Some(OciConfig::{ registry: "example", namespace_prefix: "example", }),
      warg: Some(WargConfig::{ url: "example", }),
    }),
    content="{preferred: Oci({registry: example, namespace_prefix: example}), oci: Some({registry: example, namespace_prefix: example}), warg: Some({url: example})}",
  )
  inspect(
    Show::to_string(OciDescriptor::{
      media_type: "example",
      size: 7L,
      digest: "example",
    }),
    content="{media_type: example, size: 7, digest: example}",
  )
  inspect(
    Show::to_string(OciManifest::{
      schema_version: 7,
      media_type: "example",
      config: OciDescriptor::{
        media_type: "example",
        size: 7L,
        digest: "example",
      },
      layers: [
        OciDescriptor::{ media_type: "example", size: 7L, digest: "example", },
      ],
    }),
    content="{schema_version: 7, media_type: example, config: {media_type: example, size: 7, digest: example}, layers: [{media_type: example, size: 7, digest: example}]}",
  )
  inspect(
    Show::to_string(WasmComponentInfo::{
      exports: ["example"],
      imports: ["example"],
      target: Some("example"),
    }),
    content="{exports: [example], imports: [example], target: Some(example)}",
  )
  inspect(
    Show::to_string(WasmConfig::{
      architecture: "example",
      os: "example",
      component: Some(WasmComponentInfo::{
        exports: ["example"],
        imports: ["example"],
        target: Some("example"),
      }),
    }),
    content="{architecture: example, os: example, component: Some({exports: [example], imports: [example], target: Some(example)})}",
  )
}
