//  Copyright (C) 2001, 2002 Matthew Landauer. All Rights Reserved.
//  
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of version 2 of the GNU General Public License as
//  published by the Free Software Foundation.
//
//  This program is distributed in the hope that it would be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  Further, any
//  license provided herein, whether implied or otherwise, is limited to
//  this program in accordance with the express provisions of the GNU
//  General Public License.  Patent licenses, if any, provided herein do not
//  apply to combinations of this program with other product or programs, or
//  any other product whatsoever.  This program is distributed without any
//  warranty that the program is delivered free of the rightful claim of any
//  third person by way of infringement or the like.  See the GNU General
//  Public License for more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write the Free Software Foundation, Inc., 59
//  Temple Place - Suite 330, Boston MA 02111-1307, USA.
//
// $Id$

#include <fstream>
#include <iostream>

#include "ImageFormat.h"
#include "File.h"

std::list<ImageFormat *> ImageFormat::plugins;
LibLoader ImageFormat::loader;

ImageFormat::ImageFormat()
{
	addPlugin(this);
};

ImageFormat::~ImageFormat()
{
	#ifndef __APPLE__
		removePlugin(this);
	#endif
};

// Register all the supported image types
void ImageFormat::registerPlugins()
{
  #ifndef __APPLE__
	const char formatsFilename[] = "imageFormats.conf";
	std::ifstream formats(formatsFilename);
	if (!formats) {
		std::cerr << "ImageFormat::registerPlugins(): Could not open image formats file: "
			<< formatsFilename << std::endl;
		return;
	}
	while (formats) {
		std::string libraryFilename;
		formats >> libraryFilename;
		loader.load(libraryFilename);
	}
  #endif
}

void ImageFormat::addPlugin(ImageFormat *plugin)
{
	plugins.push_back(plugin);
}

ImageFormat* ImageFormat::recentPlugin()
{
	return *(--plugins.end());
}

void ImageFormat::removePlugin(ImageFormat *plugin)
{
	plugins.remove(plugin);
}

void ImageFormat::deRegisterPlugins()
{
  #ifndef __APPLE__
	loader.releaseAll();
  #endif
}

ImageFormat* ImageFormat::recogniseByMagic(const Path &path)
{
	// Figure out what the greatest amount of the header that needs
	// to be read so that all the plugins can recognise themselves.
	int largestSizeToRecognise = 0;
	for (std::list<ImageFormat *>::iterator a = plugins.begin();
		a != plugins.end(); ++a)
		if ((*a)->sizeToRecognise() > largestSizeToRecognise)
			largestSizeToRecognise = (*a)->sizeToRecognise();
			
	// Create a temporary file object
	unsigned char *buf = new unsigned char[largestSizeToRecognise];
	File f(path);
	f.open();
	f.read(buf, largestSizeToRecognise);
	f.close();
	
	// See if any of the plugins recognise themselves.
	for (std::list<ImageFormat *>::iterator a = plugins.begin();
		a != plugins.end(); ++a)
		if ((*a)->recognise(buf)) {
			delete [] buf;
			return (*a);
		}
	delete [] buf;
	return (NULL);
}