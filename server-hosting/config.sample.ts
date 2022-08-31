export const Config = {
  // compulsory parameters

  // Factorio instance game version
  version: "latest",
  // Factorio save name
  savename: "my-save.zip",

  // server hosting region
  region: "",
  // server hosting account
  account: "",
  // prefix for all resources in this app
  prefix: "FactorioHosting",
  // set to false if you don't want an api to
  // restart game server and true if you do
  restartApi: true,

  // duck DNS entries: https://www.duckdns.org
  // you can create a token and subdomain from there
  duckDnsToken: "",
  duckDnsSubdomain: "",

  // optional parameters

  // bucket for storing save files
  // you can use an existing bucket
  // or leave it empty to create a new one
  bucketName: "",
  // server hosting vpc
  // Create a vpc and it's id here
  // or leave it empty to use default vpc
  vpcId: "",
  // specify server subnet
  // leave blank (preferred option) for auto-placement
  // If vpc is given specify subnet for that vpc
  // If vpc is not given specify subnet for default vpc
  subnetId: "",
  // Needed if subnetId is specified (i.e. us-west-2a)
  availabilityZone: "",
};
