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

// A utility class for keeping of track of file or sequence sizes using
// either a measure of bytes, Kb, Mb, etc...

#include "Size.h"

Size::Size()
{
	KBytes = 0;
}

Size::~Size()
{
}

void Size::setBytes(float n)
{
	KBytes = n / 1024;
}

void Size::setKBytes(float n)
{
	KBytes = n;
}

void Size::setMBytes(float n)
{
	KBytes = n * 1024;
}

void Size::setGBytes(float n)
{
	KBytes = n * 1024 * 1024;
}

float Size::bytes() const
{
	return KBytes * 1024;
}

float Size::kbytes() const
{
	return KBytes;
}

float Size::mbytes() const
{
	return KBytes / 1024;
}

float Size::gbytes() const
{
	return KBytes / 1024 / 1024;
}
