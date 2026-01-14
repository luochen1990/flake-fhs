{ stdenv, fetchurl }:

stdenv.mkDerivation {
  pname = "hello-custom";
  version = "2.12.1";

  src = fetchurl {
    url = "https://ftp.gnu.org/gnu/hello/hello-2.12.1.tar.gz";
    sha256 = "sha256-jZkUKval2J/UKPvqw8IldHHfwgtOi1Txn5c3Wc60pUg=";
  };

  meta = {
    description = "A program that produces a familiar, friendly greeting";
    longDescription = ''
      GNU Hello is a program that prints "Hello, world!" when you run it.
      It is the simplest example of a GNU package.
    '';
    homepage = "https://www.gnu.org/software/hello/";
    license = stdenv.lib.licenses.gpl3Plus;
    maintainers = [ stdenv.lib.maintainers.eelco ];
    platforms = stdenv.lib.platforms.all;
  };
}
