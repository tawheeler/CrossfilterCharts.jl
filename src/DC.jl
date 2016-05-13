# module DC

import Base.writemime

type DCOut
end

function writemime(io::IO, ::MIME"text/html", dcout::DCOut)
	

	# If IJulia is present, go for it
	if isdefined(Main, :IJulia)
		#=
		1 - determine chart layout
		2 - generate iframe html + js page
		3 - write link to it
		=#

		write(io, """<iframe src="src.htm" width="975" height="500"></iframe>""")
	else
		# TODO
		# decide what to do in the absence of IJulia
	end
end

# end # module

# <link href="https://cdnjs.cloudflare.com/ajax/libs/dc/1.7.5/dc.css" rel="stylesheet">
