namespace :dynamodb do
  desc "Create the single DynamoDB table + GSIs for this app (idempotent)"
  task create_table: :environment do
    client = DynamoDbClient.client
    table_name = DynamoDbClient.table_name

    existing = client.list_tables.table_names
    if existing.include?(table_name)
      puts "Table #{table_name} already exists, skipping."
      next
    end

    client.create_table(
      table_name: table_name,
      billing_mode: "PAY_PER_REQUEST",
      attribute_definitions: [
        { attribute_name: "pk", attribute_type: "S" },
        { attribute_name: "sk", attribute_type: "S" },
        { attribute_name: "gsi1pk", attribute_type: "S" },
        { attribute_name: "gsi1sk", attribute_type: "S" },
        { attribute_name: "gsi2pk", attribute_type: "S" },
        { attribute_name: "gsi2sk", attribute_type: "S" },
        { attribute_name: "gsi3pk", attribute_type: "S" },
        { attribute_name: "gsi3sk", attribute_type: "S" },
        { attribute_name: "gsi4pk", attribute_type: "S" },
        { attribute_name: "gsi4sk", attribute_type: "S" },
        { attribute_name: "gsi5pk", attribute_type: "S" },
        { attribute_name: "gsi5sk", attribute_type: "S" },
        { attribute_name: "gsi6pk", attribute_type: "S" },
        { attribute_name: "gsi6sk", attribute_type: "S" }
      ],
      key_schema: [
        { attribute_name: "pk", key_type: "HASH" },
        { attribute_name: "sk", key_type: "RANGE" }
      ],
      global_secondary_indexes: [
        gsi("GSI1", "gsi1pk", "gsi1sk"),
        gsi("GSI2", "gsi2pk", "gsi2sk"),
        gsi("GSI3", "gsi3pk", "gsi3sk"),
        gsi("GSI4", "gsi4pk", "gsi4sk"),
        gsi("GSI5", "gsi5pk", "gsi5sk"),
        gsi("GSI6", "gsi6pk", "gsi6sk")
      ]
    )

    client.wait_until(:table_exists, table_name: table_name)
    puts "Created table #{table_name}."
  end

  desc "Drop the single DynamoDB table (dev/test only, refuses in production)"
  task drop_table: :environment do
    abort("Refusing to drop the table in production") if Rails.env.production?

    client = DynamoDbClient.client
    table_name = DynamoDbClient.table_name
    client.delete_table(table_name: table_name)
    client.wait_until(:table_not_exists, table_name: table_name)
    puts "Dropped table #{table_name}."
  rescue Aws::DynamoDB::Errors::ResourceNotFoundException
    puts "Table #{table_name} did not exist."
  end

  def gsi(name, pk_attr, sk_attr)
    {
      index_name: name,
      key_schema: [
        { attribute_name: pk_attr, key_type: "HASH" },
        { attribute_name: sk_attr, key_type: "RANGE" }
      ],
      projection: { projection_type: "ALL" }
    }
  end
end
