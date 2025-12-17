class AddDmarcAndCustomMXToDomains < ActiveRecord::Migration[7.0]
  def change
    # DMARC fields
    add_column :domains, :dmarc_record, :text          # Full DMARC record value
    add_column :domains, :dmarc_status, :string        # Verification status
    add_column :domains, :dmarc_error, :string         # Verification error message

    # Custom MX records (JSON array)
    add_column :domains, :custom_mx_records, :text
  end
end
