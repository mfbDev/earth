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

#ifndef _fsobjecthandle_h_
#define _fsobjecthandle_h_

template<class C> class Handle
{
	private:
		C *ptr;
		int *count;
	public:
		Handle(C *o = NULL) : ptr(o), count(new int(1)) { };
		Handle(const Handle &h) : ptr(h.ptr), count(h.count) {
			(*count)++;
		}
		Handle& operator=(const Handle &h) {
			if (ptr != h.ptr) {
				decreaseReferenceCount();
				ptr = h.ptr;
				count = h.count;
				(*count)++;
			}
			return *this;
		}
		~Handle() { decreaseReferenceCount(); }
		C *operator->() { return ptr; };
		C *pointer() { return ptr; };
		bool null() { return (ptr == NULL); };
	private:
		void decreaseReferenceCount() {
			if (--(*count) == 0) {
				delete ptr;
				delete count;
			}
		}
};

class FsObject;

typedef Handle<FsObject> FsObjectHandle;

#endif