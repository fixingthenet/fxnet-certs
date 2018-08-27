require 'spec_helper'
#require 'fxnet_certs/certificate'

RSpec.describe FxnetCerts::Certificate do
  let(:cert) {
    FxnetCerts::Certificate.new("holla",
                                [
                                  Hashie::Mash.new(fqdn: "example.com"),
                                  Hashie::Mash.new(fqdn: "*.example.com")
                                ],
                                Pathname.new(FXNET_CERTS_FIXTURE.join("valid/certs")
                                            ))
  }
  it "initializes" do
    expect(cert.name).to eq('holla')
    expect(cert.main_domain).to eq('example.com')
    expect(cert.exist?).to be_falsy
  end
end
