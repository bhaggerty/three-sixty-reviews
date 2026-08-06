class ShareRequestRepository < BaseRepository
  def find(response_id, id)
    ShareRequest.from_item(get_item(ReviewKeys.share_request_key(response_id), ReviewKeys.share_request_key(id)))
  end

  def for_response(response_id)
    items = query(
      key_condition_expression: "pk = :pk AND begins_with(sk, :sk_prefix)",
      expression_attribute_values: {
        ":pk" => ReviewKeys.share_request_key(response_id),
        ":sk_prefix" => "SHAREREQUEST#"
      }
    )
    items.map { |item| ShareRequest.from_item(item) }
  end

  def create(share_request)
    put_item(share_request.to_item, ensure_new: true)
    share_request
  end

  # put_item is a full replace: saving a decided (non-pending) request omits
  # gsi3pk/gsi3sk from the new item entirely, which is what actually drops
  # it out of the sparse admin-queue GSI (an update_item that merely set
  # those attributes to nil would leave them present with a null value and
  # the item would still be indexed).
  def save(share_request)
    put_item(share_request.to_item)
    share_request
  end

  def pending_queue
    items = query(
      index_name: ReviewKeys::GSI3_ADMIN_SHARE_QUEUE,
      key_condition_expression: "gsi3pk = :pk",
      expression_attribute_values: { ":pk" => "SHAREQUEUE#PENDING" }
    )
    items.map { |item| ShareRequest.from_item(item) }
  end
end
