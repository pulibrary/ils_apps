# frozen_string_literal: true
# access alma xml invoice list and make it accessible for processing
module PeoplesoftVoucher
  class AlmaXmlInvoiceList
    attr_reader :xml_file, :invoices, :sftp_locations, :alma_sftp, :file_pattern, :input_ftp_base_dir

    delegate :empty?, to: :valid_invoices

    def initialize(input_ftp_base_dir: Rails.application.config.alma_ftp.voucher_feed_path, file_pattern: '\.xml$', alma_sftp: AlmaSftp.new)
      @input_ftp_base_dir = input_ftp_base_dir
      @file_pattern = file_pattern
      @alma_sftp = alma_sftp
      @sftp_locations = []
      @invoices = []
      download_invoices
    end

    def mark_files_as_processed
      alma_sftp.start do |sftp|
        sftp_locations.each do |location|
          sftp.rename(location, "#{location}.processed")
        end
      end
    end

    def mark_files_as_error
      alma_sftp.start do |sftp|
        sftp_locations.each do |location|
          sftp.rename(location, "#{location}.error")
        end
      end
    end

    def status_report(cvs_invoices: invoices)
      return "" if invoices.empty?
      CSV.generate do |csv|
        csv << ["Lib Vendor Invoice Date", "Invoice No", "Vendor Code", "Vendor Id", "Invoice Amount", "Invoice Curency", "Local Amount", "Voucher ID", "Errors"]
        cvs_invoices.each do |invoice|
          csv << [invoice.invoice_date, invoice.id, invoice.vendor_code, invoice.vendor_id, invoice.total_invoice_amount,
                  invoice.invoice_currency, invoice.invoice_local_amount_total, invoice.voucher_id, invoice.errors.join(', ')]
        end
      end
    end

    def onbase_report
      CSV.generate(force_quotes: true) do |csv|
        valid_invoices.each do |invoice|
          csv << [invoice.invoice_date, invoice.id, invoice.vendor_code, invoice.total_invoice_amount, invoice.voucher_id]
        end
      end
    end

    def errors
      invoices.map do |invoice|
        "#{invoice.id}\t#{invoice.unique_identifier}\t#{invoice.errors.join(', ')}" unless invoice.valid?
      end.compact
    end

    def error_invoices
      invoices.reject(&:valid?)
    end

    def valid_invoices
      invoices.select(&:valid?)
    end

    private

    def download_invoices
      alma_sftp.start do |sftp|
        sftp.dir.foreach(input_ftp_base_dir) do |entry|
          next unless /#{file_pattern}/.match?(entry.name)
          filename = File.join(input_ftp_base_dir, entry.name)
          data = sftp.download!(filename)
          doc = Nokogiri::XML(StringIO.new(data))
          sftp_locations << filename
          current_invoices = doc.xpath('//xmlns:invoice_list/xmlns:invoice').map { |xml_invoice| PeoplesoftVoucher::AlmaXmlInvoice.new(xml_invoice: xml_invoice) }
          @invoices += current_invoices
        end
      end
    end
  end
end
