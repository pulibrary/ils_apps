# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PeoplesoftVoucher::VoucherFeedCheck, type: :model do
  let(:today) { Time.zone.now.strftime("%m%d%Y") }
  let(:onbase_today) { Time.zone.now .strftime("%Y%m%d") }
  let(:sftp_entry1) { instance_double("Net::SFTP::Protocol::V01::Name", name: "abc.xml") }
  let(:sftp_session) { instance_double("Net::SFTP::Session", dir: sftp_dir) }
  let(:sftp_dir) { instance_double("Net::SFTP::Operations::Dir") }

  describe "#run" do
    it "validates non processed ids" do
      allow(sftp_dir).to receive(:foreach).and_yield(sftp_entry1)
      allow(sftp_session).to receive(:download!).with("/alma/invoices/abc.xml").and_return(Rails.root.join('spec', 'fixtures', 'invoice_export_202118300518.xml').read)
      allow(Net::SFTP).to receive(:start).and_yield(sftp_session)

      voucher_feed_check = described_class.new()
      expect { expect(voucher_feed_check.run).to be_truthy }.to change { ActionMailer::Base.deliveries.count }.by(0)
                                                            .and change { PeoplesoftInvoice.count }.by(1)
      expect(sftp_session).to have_received(:download!).with("/alma/invoices/abc.xml")
      expect(PeoplesoftInvoice.last.invoice_id).to eq("PO-9999")
    end

    it "errors for an already processed id" do
      allow(sftp_dir).to receive(:foreach).and_yield(sftp_entry1)
      allow(sftp_session).to receive(:download!).with("/alma/invoices/abc.xml").and_return(Rails.root.join('spec', 'fixtures', 'invoice_export_202118300518.xml').read)
      allow(sftp_session).to receive(:rename).with("/alma/invoices/abc.xml", "/alma/invoices/abc.xml.error")
      allow(Net::SFTP).to receive(:start).and_yield(sftp_session)
      PeoplesoftInvoice.create(invoice_id: "PO-9999")

      voucher_feed_check = described_class.new()
      expect { expect(voucher_feed_check.run).to be_falsey }.to change { ActionMailer::Base.deliveries.count }.by(1)
                                                            .and change { PeoplesoftInvoice.count }.by(0)
      expect(sftp_session).to have_received(:download!).with("/alma/invoices/abc.xml")
      expect(sftp_session).to have_received(:rename).with("/alma/invoices/abc.xml", "/alma/invoices/abc.xml.error")
    end
  end
end
