# frozen_string_literal: true

class HololibZip
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :size, :integer
  attribute :size_mb, :float
  attribute :modified, :string

  class << self
    def all(storage: default_storage)
      storage.list_hololib_zips.map { |attributes| new(attributes) }
    end

    def upload(file, storage: default_storage, operations: default_operations)
      save_result = storage.save_zip(file)
      return save_result unless save_result[:status] == :saved

      import_result = operations.import_zip(save_result[:filename])
      {
        status: :uploaded,
        filename: save_result[:filename],
        import: import_result
      }
    end

    def remove(filename, storage: default_storage)
      storage.delete_zip(filename)
    end

    private

    def default_storage
      RccRemote::StorageService.new
    end

    def default_operations
      RccRemote::OperationsService.new
    end
  end
end
