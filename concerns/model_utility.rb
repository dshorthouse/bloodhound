module ModelUtility

  extend ActiveSupport::Concern

  def custom_attributes
    Hash[self.class.custom_attribute_names.zip attributes.values]
  end

  class_methods do

    def custom_attribute_mappings
      Hash[attribute_names.zip(custom_attribute_names)]
    end

    def custom_attribute(new_attribute, old_attribute)
      alias_attribute new_attribute, old_attribute
      custom_attribute_names.map! { |x| x == old_attribute.to_s ? new_attribute.to_s : x }
    end

    def custom_attribute_names
      @custom_attribute_names ||= attribute_names.dup
    end

  end

end