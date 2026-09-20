"""Build native dependencies for the local pod5r development environment."""

from conan import ConanFile
from conan.tools.cmake import CMakeDeps, CMakeToolchain


class Pod5rNativeDependencies(ConanFile):
    settings = "os", "arch", "compiler", "build_type"

    requires = (
        "arrow/18.0.0",
        "flatbuffers/2.0.8",
        "zstd/1.5.7",
        "zlib/1.3.1",
    )

    default_options = {
        "arrow/*:shared": False,
        "arrow/*:fPIC": True,
        "arrow/*:parquet": False,
        "arrow/*:with_boost": False,
        "arrow/*:with_thrift": False,
        "arrow/*:with_zstd": True,
        "arrow/*:with_zlib": True,
        "arrow/*:with_jemalloc": False,
        "arrow/*:with_mimalloc": False,
        "flatbuffers/*:shared": False,
        "flatbuffers/*:fPIC": True,
        "zstd/*:shared": False,
        "zstd/*:fPIC": True,
        "zstd/*:build_programs": False,
        "zlib/*:shared": False,
        "zlib/*:fPIC": True,
    }

    def generate(self):
        """Generate dependency locations and a compiler toolchain for CMake."""
        toolchain = CMakeToolchain(self)
        toolchain.generate()

        dependencies = CMakeDeps(self)
        dependencies.set_property("arrow", "cmake_target_name", "arrow::arrow")
        dependencies.set_property("flatbuffers", "cmake_file_name", "Flatbuffers")
        dependencies.set_property("zstd", "cmake_target_name", "zstd::zstd")
        dependencies.generate()
