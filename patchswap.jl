using Colors
using Images
using CoordinateTransformations
using Rotations
using FileIO
using TestImages
using IterTools
using Random

img_path = "input_image.jpg"
img_ = float.(load(img_path))

# Use this to crop to AoI
#img_ = @view img_[250:1250, 1000:2000]
#img_ = @view img_[250:1250, 1:1000]

function bounds(cur_size::Int, target_size::Int)::Tuple{Int, Int}
	diff = cur_size - target_size
	return (floor(diff / 2) + 1, floor(cur_size - (diff / 2)))
end

function patch_shuffle(prob_swap, patches_per_dim)
	patch_range = collect(1:patches_per_dim)
	patch_ids = collect(product(patch_range, patch_range))
	num_patches_start = length(Set(patch_ids))

	for i in 1:patches_per_dim-1
		for j in reverse(2:patches_per_dim)
			c = patch_ids[i, j]
			u = patch_ids[i+1, j]
			l = patch_ids[i, j-1]

			if rand() < prob_swap
				patch_ids[i, j] = u
				patch_ids[i+1, j] = c
				c = u
			end

			if rand() < prob_swap
				patch_ids[i, j] = l
				patch_ids[i, j-1] = c
				c = l
			end

		end
	end

	@assert num_patches_start == length(Set(patch_ids))
	return patch_ids
end

function build_channel(img, patch_locs, patch_width)
	new_img = Array{Float32}(undef, size(img))
	for i::Int = 1:size(patch_locs, 1)
		for j::Int = 1:size(patch_locs, 2)
			i_ = i-1
			j_ = j-1
			loc = patch_locs[i, j]
			li = loc[1]
			lj = loc[2]
			nei = i * patch_width
			nsi = nei - patch_width + 1
			nej = j * patch_width
			nsj = nej - patch_width + 1

			oei = li * patch_width
			osi = oei - patch_width + 1
			oej = lj * patch_width
			osj = oej - patch_width + 1

			new_img[nsi:nei, nsj:nej] = img[osi:oei, osj:oej]
		end
	end
	return new_img
end

@doc"""
img: Input image loaded from JuliaImage
patch_width: Size of each image patch (px)
swaprate: Probablity to swap a pair of patches
rotation: How much to rotate the channels of the image in the final image
crop_width: Size of resulting image. Image will be center cropped square to the specified size
"""
function build_img(img, patch_width, swaprate, rotation, crop_width)
	#img = HSV.(img)
	shape = size(img)
	patches_per_dim = convert(Int, floor(crop_width / patch_width))

	y_bounds = bounds(shape[1], crop_width)
	x_bounds = bounds(shape[2], crop_width)

	img = @view img[y_bounds[1]:y_bounds[2], x_bounds[1]:x_bounds[2]]
	channels = channelview(img)
	r = channels[1, :, :]
	g = channels[2, :, :]
	b = channels[3, :, :]

	img_r = imrotate(r, rotation, axes(img))
	img_g = imrotate(g, 0, axes(img))
	img_b = imrotate(b, -rotation, axes(img))

	new_r = build_channel(img_r, patch_shuffle(swaprate, patches_per_dim), patch_width)
	new_g = build_channel(img_g, patch_shuffle(swaprate, patches_per_dim), patch_width)
	new_b = build_channel(img_b, patch_shuffle(swaprate, patches_per_dim), patch_width)
	RGB_diffview = colorview(RGB, channelview(new_r), channelview(new_g), channelview(new_b))
	return RGB_diffview
end

build_img(img_, 333, 0.2, pi / 64, 1000)