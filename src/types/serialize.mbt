///|
pub fn RegistryConfig::to_json(self : RegistryConfig) -> Json {
  let obj : Map[String, Json] = {}
  match self.preferred {
    Oci(oci) => {
      let pref : Map[String, Json] = {}
      pref["type"] = Json::string("oci")
      pref["registry"] = Json::string(oci.registry)
      pref["namespacePrefix"] = Json::string(oci.namespace_prefix)
      obj["preferred"] = Json::object(pref)
    }
    Warg(warg) => {
      let pref : Map[String, Json] = {}
      pref["type"] = Json::string("warg")
      pref["url"] = Json::string(warg.url)
      obj["preferred"] = Json::object(pref)
    }
  }
  match self.oci {
    Some(oci) => {
      let o : Map[String, Json] = {}
      o["registry"] = Json::string(oci.registry)
      o["namespacePrefix"] = Json::string(oci.namespace_prefix)
      obj["oci"] = Json::object(o)
    }
    None => ()
  }
  match self.warg {
    Some(warg) => {
      let w : Map[String, Json] = {}
      w["url"] = Json::string(warg.url)
      obj["warg"] = Json::object(w)
    }
    None => ()
  }
  Json::object(obj)
}

///|
pub fn OciDescriptor::to_json(self : OciDescriptor) -> Json {
  let obj : Map[String, Json] = {}
  obj["mediaType"] = Json::string(self.media_type)
  obj["size"] = Json::number(self.size.to_double())
  obj["digest"] = Json::string(self.digest)
  Json::object(obj)
}

///|
pub fn OciManifest::to_json(self : OciManifest) -> Json {
  let obj : Map[String, Json] = {}
  obj["schemaVersion"] = Json::number(self.schema_version.to_double())
  obj["mediaType"] = Json::string(self.media_type)
  obj["config"] = self.config.to_json()
  let layers : Array[Json] = []
  for layer in self.layers {
    layers.push(layer.to_json())
  }
  obj["layers"] = Json::array(layers)
  Json::object(obj)
}

///|
pub fn WasmConfig::to_json(self : WasmConfig) -> Json {
  let obj : Map[String, Json] = {}
  obj["architecture"] = Json::string(self.architecture)
  obj["os"] = Json::string(self.os)
  match self.component {
    Some(comp) => {
      let c : Map[String, Json] = {}
      let exports : Array[Json] = []
      for e in comp.exports {
        exports.push(Json::string(e))
      }
      c["exports"] = Json::array(exports)
      let imports : Array[Json] = []
      for i in comp.imports {
        imports.push(Json::string(i))
      }
      c["imports"] = Json::array(imports)
      match comp.target {
        Some(t) => c["target"] = Json::string(t)
        None => ()
      }
      obj["component"] = Json::object(c)
    }
    None => ()
  }
  Json::object(obj)
}
