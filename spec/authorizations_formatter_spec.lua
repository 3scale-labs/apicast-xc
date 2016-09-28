describe('authorizations_formatter', function()
  local formatter = require 'xc/authorizations_formatter'

  describe('authorization', function()
    describe('when the value is nil', function()
      it('returns nil', function()
        assert.is_nil(formatter.authorization(nil))
      end)
    end)

    describe('when the value is not a string', function()
      it('returns nil', function()
        assert.is_nil(formatter.authorization(123))
      end)
    end)

    describe('when the value is a string that represents an OK authorization', function()
      it('returns true', function()
        assert.is_true(formatter.authorization('1'))
      end)
    end)

    describe('when the value is a string that represents a denied authorization', function()
      describe('and it contains a reason', function()
        local deny_reason = 'a_reason'

        it('returns false and the reason', function()
          local auth, reason = formatter.authorization('0:'..deny_reason)
          assert.is_false(auth)
          assert.are_equal(deny_reason, reason)
        end)
      end)

      describe('and it does not contain a reason', function()
        it('returns false', function()
          assert.is_false(formatter.authorization('0'))
        end)
      end)
    end)
  end)
end)
