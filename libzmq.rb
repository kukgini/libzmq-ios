#!/usr/bin/env ruby

#
# A script to download and build libzmq for iOS written in Ruby, including arm64
# Adapted from https://github.com/azawawi/libzmq-ios
#

# set -e

require "FileUtils"

# for now
exit 1

LIBNAME="libzmq.a"
ROOTDIR=Dir.pwd

#libsodium
LIBSODIUM_DIST="#{ROOTDIR}/libsodium-ios/libsodium_dist/"
puts "Building dependency 'libsodium-ios'..."
FileUtils.cd 'libsodium-ios'
system 'libsodium.sh'
FileUtils.cd ROOTDIR

ARCHS=["armv7", "armv7s", "arm64", "i386", "x86_64"]
DEVELOPER=`xcode-select -print-path`
LIPO=`xcrun -sdk iphoneos -find lipo`

# Script's directory
SCRIPTDIR=File.dirname(__FILE__)

# libsodium root directory
LIBDIR="libzeromq"
FileUtils.mkdir_p LIBDIR

LIBDIR=File.dirname(LIBDIR)

# Destination directory for build and install
DSTDIR     = SCRIPTDIR
BUILDDIR   = "#{DSTDIR}/libzmq_build"
DISTDIR    = "#{DSTDIR}/libzmq_dist"
DISTLIBDIR = "#{DISTDIR}/lib"
TARVER     = "4.1.6"
TARNAME    = "zeromq-$TARVER"
TARFILE    = "#{TARNAME}.tar.gz"
TARURL     = "https://github.com/zeromq/zeromq4-1/releases/download/v#{TARVER}/#{TARFILE}"

# http://libwebp.webm.googlecode.com/git/iosbuild.sh
# Extract the latest SDK version from the final field of the form: iphoneosX.Y
# SDK=$(xcodebuild -showsdks \
#     | grep iphoneos | sort | tail -n 1 | awk '{print substr($NF, 9)}'
#     )
# 
IOS_VERSION_MIN = 9.0
OTHER_LDFLAGS   = ""
OTHER_CFLAGS    = "-Os -Qunused-arguments"
# Enable Bitcode
OTHER_CPPFLAGS  = "-Os -I#{LIBSODIUM_DIST}/include -fembed-bitcode"
OTHER_CXXFLAGS  ="-Os"

# Download and extract ZeroMQ
FileUtils.rm_rf LIBDIR
# set -e
# curl -O -L $TARURL
# tar xzf $TARFILE
FileUtils.rm TARFILE
FileUtils.mv TARNAME, LIBDIR
 
# Cleanup
if File.directory? BUILDDIR
  FileUtils.rm_rf BUILDDIR
end
if File.directory? DISTDIR
  FileUtils.rm_rf DISTDIR
end
FileUtils.mkdir_p BUILDDIR
FileUtils.mkdir_p DISTDIR

# Generate autoconf files
FileUtils.cd LIBDIR

def build_armv7
  platform        = "iPhoneOS"
  host            = "#{ARCH}-apple-darwin"
  ENV["BASEDIR"]  = "#{DEVELOPER}/Platforms/#{platform}.platform/Developer"
  ENV["ISDKROOT"] = "#{BASEDIR}/SDKs/#{platform}#{SDK}.sdk"
  ENV["CXXFLAGS"] = "#{OTHER_CXXFLAGS}"
  ENV["CPPFLAGS"] = "-arch #{ARCH} -isysroot #{ISDKROOT} -mios-version-min=#{IOS_VERSION_MIN} #{OTHER_CPPFLAGS}"
  ENV["LDFLAGS"]  = "-arch #{ARCH} -isysroot #{ISDKROOT} #{OTHER_LDFLAGS}"
end

def build_armv7s
  platform        = "iPhoneOS"
  host            = "#{ARCH}-apple-darwin"
  ENV["BASEDIR"]  = "#{DEVELOPER}/Platforms/#{platform}.platform/Developer"
  ENV["ISDKROOT"] = "#{BASEDIR}/SDKs/#{platform}#{SDK}.sdk"
  ENV["CXXFLAGS"] = "#{OTHER_CXXFLAGS}"
  ENV["CPPFLAGS"] = "-arch #{ARCH} -isysroot #{ISDKROOT} -mios-version-min=#{IOS_VERSION_MIN} #{OTHER_CPPFLAGS}"
  ENV["LDFLAGS"]  = "-arch #{ARCH} -isysroot #{ISDKROOT} #{OTHER_LDFLAGS}"
end

def build_arm64
  platform        = "iPhoneOS"
  host            = "arm-apple-darwin"
  ENV["BASEDIR"]  = "#{DEVELOPER}/Platforms/#{platform}.platform/Developer"
  ENV["ISDKROOT"] = "#{BASEDIR}/SDKs/#{platform}#{SDK}.sdk"
  ENV["CXXFLAGS"] = "#{OTHER_CXXFLAGS}"
  ENV["CPPFLAGS"] = "-arch #{ARCH} -isysroot #{ISDKROOT} -mios-version-min=#{IOS_VERSION_MIN} #{OTHER_CPPFLAGS}"
  ENV["LDFLAGS"]  = "-arch #{ARCH} -isysroot #{ISDKROOT} #{OTHER_LDFLAGS}"
end

def build_i386
  platform        = "iPhoneSimulator"
  host            = "#{ARCH}-apple-darwin"
  ENV["BASEDIR"]  = "#{DEVELOPER}/Platforms/#{platform}.platform/Developer"
  ENV["ISDKROOT"] = "#{BASEDIR}/SDKs/#{platform}#{SDK}.sdk"
  ENV["CXXFLAGS"] = "#{OTHER_CXXFLAGS}"
  ENV["CPPFLAGS"] = "-m32 -arch #{ARCH} -isysroot #{ISDKROOT} -mios-version-min=#{IOS_VERSION_MIN} #{OTHER_CPPFLAGS}"
  ENV["LDFLAGS"]  = "-m32 -arch #{ARCH} #{OTHER_LDFLAGS}"
end

def build_x86_64
  platform        = "iPhoneSimulator"
  host            = "#{ARCH}-apple-darwin"
  ENV["BASEDIR"]  = "#{DEVELOPER}/Platforms/#{platform}.platform/Developer"
  ENV["ISDKROOT"] = "#{BASEDIR}/SDKs/#{platform}#{SDK}.sdk"
  ENV["CXXFLAGS"] = "#{OTHER_CXXFLAGS}"
  ENV["CPPFLAGS"] = "-arch #{ARCH} -isysroot #{ISDKROOT} -mios-version-min=#{IOS_VERSION_MIN} #{OTHER_CPPFLAGS}"
  ENV["LDFLAGS"]  = "-arch #{ARCH} #{OTHER_LDFLAGS}"
end

# Iterate over archs and compile static libs
liblist = []
for ARCH in ARCHS
  BUILDARCHDIR="#{BUILDDIR}/#{ARCH}"
  FileUtils.mkdir_p BUILDARCHDIR
  
  case ARCH
    when "armv7"
      build_armv7()
    when "armv7s"
      build_armv7s()
    when "arm64"
      build_arm64()
    when "i386"
      build_i386()
    when "x86_64"
      build_x86_64()
    else
      puts "Unsupported architecture '#{ARCH}'"
      exit 1
  end

  ENV["PATH"] = "#{DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin:#{DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/sbin:#{ENV["PATH"]}"
  puts "Configuring for #{ARCH}..."

# 
#     set +e
#     cd #{LIBDIR} && make distclean
#     set -e
#     #{LIBDIR}/configure \
# 	--prefix=#{BUILDARCHDIR} \
# 	--disable-shared \
# 	--enable-static \
# 	--host=#{HOST}\
# 	--with-libsodium=#{LIBSODIUM_DIST}
 
  puts "Building #{LIBNAME} for #{ARCH}..."
  FileUtils.cd LIBDIR

  # Workaround to disable clock_gettime since it is only available on iOS 10+
  FileUtils.cp("../platform-patched.hpp", "src/platform.hpp")
   
  system "make -j8 V=0"
  system "make install"

  liblist.push "#{BUILDARCHDIR}/lib/#{LIBNAME}"
end
 
# Copy headers and generate a single fat library file
FileUtils.mkdir_p DISTLIBDIR
system "#{LIPO} -create #{liblist.join(" ")} -output #{DISTLIBDIR}/#{LIBNAME}"

for ARCH in $ARCHS
  FileUtils.cp_r "#{BUILDDIR}/#{ARCH}/include", DISTDIR
  break
end

# Cleanup
FileUtils.rm_rf BUILDDIR
