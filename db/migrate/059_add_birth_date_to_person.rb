require File.dirname(__FILE__) + '/../../config/environment'

class AddBirthDateToPerson < ActiveRecord::Migration

  class ConvertDates
    def self.convert(date_string)
      return if date_string.blank?
      return date_string if date_string.kind_of?(Date)
      return unless date_string.kind_of?(String)
      return if date_string =~ /[a-zA-Z]/

      if date_string =~ /^\d\d([^\d]+)\d\d$/
        date_string += $1 + (Date.today.year - 100).to_s
      end

      if date_string =~ /[^\d](\d\d)$/
        year = $1.to_i
        date_string = date_string[0..-3] + (year > (Date.today.year - 2000) ? year + 1900 : year + 2000).to_s
      end

      if ! ((date_string =~ /(\d+)[^\d]+(\d+)[^\d]+(\d+)/) || (date_string =~ /^(\d\d)(\d\d)(\d\d\d\d)$/))
        return nil
      end
      begin
        Date.new($3.to_i, $2.to_i, $1.to_i)
      rescue Exception => e
        nil
      end
    end
  end

  class Person < ActiveRecord::Base
    set_table_name 'profiles'
    serialize :data, Hash
  end

  def self.up
    add_column :profiles, :birth_date, :date
    Person.find(:all).select{|p| p.type = 'Person'}.each do |p|
      p.birth_date = ConvertDates.convert(p.data[:birth_date].to_s)
      p.save
    end
  end

  def self.down
    remove_column :profiles, :birth_date
  end
end

if $PROGRAM_NAME == __FILE__
  require File.dirname(__FILE__) + '/../../test/test_helper'

  class ConvertDatesTest <  Test::Unit::TestCase

    should 'convert with slash' do
      date = AddBirthDateToPerson::ConvertDates.convert('10/01/2009')
      assert_equal [10, 1, 2009], [date.day, date.month, date.year]
    end

    should 'convert with hyphen' do
      date = AddBirthDateToPerson::ConvertDates.convert('10-01-2009')
      assert_equal [10, 1, 2009], [date.day, date.month, date.year]
    end

    should 'convert with dot' do
      date = AddBirthDateToPerson::ConvertDates.convert('10.01.2009')
      assert_equal [10, 1, 2009], [date.day, date.month, date.year]
    end

    should 'convert with slash and space' do
      date = AddBirthDateToPerson::ConvertDates.convert('10/ 01/ 2009')
      assert_equal [10, 1, 2009], [date.day, date.month, date.year]
    end

    should 'convert with empty to nil' do
      date = AddBirthDateToPerson::ConvertDates.convert('')
      assert_nil date
    end

    should 'convert with nil to nil' do
      date = AddBirthDateToPerson::ConvertDates.convert(nil)
      assert_nil date
    end

    should 'convert with two digits 1900' do
      date = AddBirthDateToPerson::ConvertDates.convert('10/01/99')
      assert_equal [10, 1, 1999], [date.day, date.month, date.year]
    end

    should 'convert with two digits 2000' do
      date = AddBirthDateToPerson::ConvertDates.convert('10/01/09')
      assert_equal [10, 1, 2009], [date.day, date.month, date.year]
    end

    should 'convert with two numbers' do
      date = AddBirthDateToPerson::ConvertDates.convert('10/01')
      assert_equal [10, 1, (Date.today.year - 100)], [date.day, date.month, date.year]
    end

    should 'convert to nil if non-numeric date' do
      date = AddBirthDateToPerson::ConvertDates.convert('10 de agosto de 2009')
      assert_nil date
    end

    should 'do nothing if date' do
      date = AddBirthDateToPerson::ConvertDates.convert(Date.today)
      assert_equal Date.today, date
    end

    should 'return nil when not string nor date' do
      date = AddBirthDateToPerson::ConvertDates.convert(1001)
      assert_nil date
    end

    should 'convert date without separators' do
      date = AddBirthDateToPerson::ConvertDates.convert('27071977')
      assert_equal [ 1977, 07, 27] , [date.year, date.month, date.day]
    end

    should 'not try to create invalid date' do
      assert_nil AddBirthDateToPerson::ConvertDates.convert('70/05/1987')
    end

  end

end
