# FILENAME: package.nix
{
  llvmPackages_23,
  cmake,
  pkg-config,
  gtest,
  src,
  cmakeOnly ? false,
}:
llvmPackages_23.stdenv.mkDerivation {
  inherit src;
  pname = if cmakeOnly then "theta-cmake" else "theta-utils";
  version = "0.1.0";

  outputs = [ "out" ];

  buildInputs = if cmakeOnly then [ ] else [ gtest ];

  propagatedBuildInputs = [ ];

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  cmakeFlags = if cmakeOnly then [ "-DTHETA_UTILS_CMAKE_ONLY=ON" ] else [ ];

  dontStrip = true;
  cmakeBuildType = "Release";
  separateDebugInfo = false;

  doCheck = false;
}
