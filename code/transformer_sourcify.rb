require 'sourcify'

class Rewriter
  def process(exp)
    if exp[3].is_a?(Sexp) and exp[3][0] == :block
      iter, call, nil_val, block = exp.shift, exp.shift, exp.shift, exp.shift
      s(iter, call, nil_val, *rewrite_assignments(block[1..-1]))
    else
      exp
    end
  end

  def rewrite_assignments exp
    return [] if exp.empty?

    head = exp.shift

    if head[0] == :lasgn
      var_name = head[1]
      expression = head[2]

      body = rewrite_assignments(exp)

      if body.first.is_a? Symbol
        body = [s(*body)]
      end

      [s(:iter,
        s(:call, nil, :bind, s(:arglist, expression)),
        s(:lasgn, var_name),
        *body)]
    elsif exp.empty?
      [head]
    else
      [s(:iter,
        s(:call, nil, :bind_const, s(:arglist, head)),
        nil,
        *rewrite_assignments(exp))]
    end
  end
end

module Transformer
  def run(&block)
    eval(ruby_for(block), block.binding).call
  end

  def ruby_for(block)
    "#{self.name}.instance_eval { #{transform(block)} }"
  end

  def transform(block)
    Ruby2Ruby.new.process(
      Rewriter.new.process(block.to_sexp))
  end

  # def bind_const(value, &block)
  #   bind(value) { block.call }
  # end
end

