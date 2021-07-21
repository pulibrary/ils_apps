# frozen_string_literal: true
module PeoplesoftVoucher
  class VoucherFeedCheck
    attr_reader :alma_xml_invoice_list

    # the inputs are ftp
    def initialize(alma_xml_invoice_list: PeoplesoftVoucher::AlmaXmlInvoiceList.new)
      @alma_xml_invoice_list = alma_xml_invoice_list
    end

    def run
      ids = alma_xml_invoice_list.invoices.map(&:id)
      already_processed = ids.select{ |id| PeoplesoftInvoice.where(invoice_id: id).count.positive? }
      if already_processed.count.positive?
        InvoiceErrorMailer.report(duplicate_ids: already_processed).deliver
        alma_xml_invoice_list.mark_files_as_error
      else
        ids.each {|id| PeoplesoftInvoice.create(invoice_id: id)}
      end
      already_processed.empty?
    end

  end
end
