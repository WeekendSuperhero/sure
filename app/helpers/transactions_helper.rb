module TransactionsHelper
  def transaction_search_filters
    [
      { key: "account_filter", label: t("transactions.search.filters.account"), icon: "layers" },
      { key: "date_filter", label: t("transactions.search.filters.date"), icon: "calendar" },
      { key: "type_filter", label: t("transactions.search.filters.type"), icon: "tag" },
      { key: "status_filter", label: t("transactions.search.filters.status"), icon: "clock" },
      { key: "amount_filter", label: t("transactions.search.filters.amount"), icon: "hash" },
      { key: "category_filter", label: t("transactions.search.filters.category"), icon: "shapes" },
      { key: "tag_filter", label: t("transactions.search.filters.tag"), icon: "tags" },
      { key: "merchant_filter", label: t("transactions.search.filters.merchant"), icon: "store" }
    ]
  end

  def get_transaction_search_filter_partial_path(filter)
    "transactions/searches/filters/#{filter[:key]}"
  end

  def get_default_transaction_search_filter
    transaction_search_filters[0]
  end

  def in_split_group?(entry, params_grouped)
    entry.split_child? && Current.user.show_split_grouped? && params_grouped == "true"
  end

  # ---- Transaction extra details helpers ----
  # Returns a structured hash describing extra details for a transaction.
  # Input can be a Transaction or an Entry (responds_to :transaction).
  # Structure:
  #   {
  #     kind: :simplefin | :plaid | :raw,
  #     simplefin: { payee:, description:, memo: },
  #     plaid: { original_description:, payment_channel:, transaction_code: },
  #     provider_extras: [ { key:, value:, title: } ],
  #     raw: String (pretty JSON or string)
  #   }
  def build_transaction_extra_details(obj)
    tx = obj.respond_to?(:transaction) ? obj.transaction : obj
    return nil unless tx.respond_to?(:extra) && tx.extra.present?

    extra = tx.extra

    if extra.is_a?(Hash) && extra["simplefin"].present?
      sf = extra["simplefin"]
      simple = {
        payee: sf.is_a?(Hash) ? sf["payee"].presence : nil,
        description: sf.is_a?(Hash) ? sf["description"].presence : nil,
        memo: sf.is_a?(Hash) ? sf["memo"].presence : nil
      }.compact

      extras = []
      if sf.is_a?(Hash) && sf["extra"].is_a?(Hash) && sf["extra"].present?
        sf["extra"].each do |k, v|
          extras << provider_extra_row(k, v)
        end
      end

      {
        kind: :simplefin,
        simplefin: simple,
        plaid: {},
        provider_extras: extras,
        raw: nil
      }
    elsif extra.is_a?(Hash) && extra["plaid"].present?
      plaid = extra["plaid"]
      simple = {
        original_description: plaid.is_a?(Hash) ? plaid["original_description"].presence : nil,
        payment_channel: plaid.is_a?(Hash) ? plaid["payment_channel"].presence : nil,
        transaction_code: plaid.is_a?(Hash) ? plaid["transaction_code"].presence : nil
      }.compact

      extras = []
      if plaid.is_a?(Hash)
        if plaid["payment_meta"].is_a?(Hash) && plaid["payment_meta"].present?
          plaid["payment_meta"].each do |k, v|
            extras << provider_extra_row("payment_meta.#{k}", v)
          end
        end

        if plaid["counterparties"].is_a?(Array) && plaid["counterparties"].present?
          plaid["counterparties"].each_with_index do |counterparty, index|
            extras << provider_extra_row("counterparty_#{index + 1}", counterparty)
          end
        end
      end

      # Only show Additional details when there is something beyond pending flags
      return nil if simple.blank? && extras.blank?

      {
        kind: :plaid,
        simplefin: {},
        plaid: simple,
        provider_extras: extras,
        raw: nil
      }
    else
      pretty = begin
        JSON.pretty_generate(extra)
      rescue StandardError
        extra.to_s
      end
      {
        kind: :raw,
        simplefin: {},
        plaid: {},
        provider_extras: [],
        raw: pretty
      }
    end
  end

  def provider_extra_row(key, value)
    display = (value.is_a?(Hash) || value.is_a?(Array)) ? value.to_json : value
    {
      key: key.to_s.humanize,
      value: display,
      title: (value.is_a?(String) ? value : display.to_s)
    }
  end
end
