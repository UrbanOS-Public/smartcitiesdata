
method=$1

case $method in
    all)
	mix test
	;;
    *)
        mix test  --max-failures=5 --timeout=35
       ;;
esac
