# Copyright (C) 2007 Michael Homer
# Released under the GNU GPL

require 'tsort'
class DependencyHash < Hash
	include TSort
	alias tsort_each_node each_key
	attr_accessor :introducedBy
	def tsort_each_child(node, &block)
		if has_key?(node)
			fetch(node).each(&block)
		end
	end
end

def createDepHash(toup)
	# Local alias to save typing
	except = @config['except']
	introducedBy = {}
	dh = DependencyHash.new
	toup.each {|prog, ver|
		introducedBy[prog] = nil
		dh[prog] = getDependencies(prog, ver)
		# SPECIAL CASE: circular dependency
		if prog=='Xorg' and dh[prog].include?('Mesa')
			#self.logError "Circular dependency of Xorg on Mesa removed from tree"
			dh[prog]-= ['Mesa']
		end
	}
	# This ensures that the complete dependencies of every program are included in the tree.
	begin
		mh = {}
		dh.each {|prog, deps|
			deps.each {|dep|
				next if dep.nil? || dep==""
				if !dh[dep]
					introducedBy[dep] = prog
					mh[dep] = getDependencies(dep, getNewestAvailableVersion(dep, prog))
				end
			}
		}
		dh.merge(mh)
	end while mh.size>0
	begin
		todel = []
		dh.each {|k, v|
			if except.include?(k)
				todel.push k
				next
			end
			v.each {|d|
				next if !d || d==""
				if except.include?(d) || !dh[d] # If this has an excluded or non-present dependency,
					todel.push k # drop it completely.
					break
				end
			}
		}
		todel.each {|item| # Delete them and go again
			#puts "Actually deleting #{item}"
			dh.delete item
		}
	end while todel.length>0
	dh.introducedBy = introducedBy
	return dh
end
