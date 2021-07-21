class CreatePeoplesoftInvoices < ActiveRecord::Migration[5.2]
  def change
    create_table :peoplesoft_invoices do |t|
      t.string :invoice_id

      t.timestamps
    end
  end
end
