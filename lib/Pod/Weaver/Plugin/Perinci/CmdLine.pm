package Pod::Weaver::Plugin::Perinci::CmdLine;

use 5.010001;
use Moose;
with 'Pod::Weaver::Role::AddTextToSection';
with 'Pod::Weaver::Role::Section';

# AUTHORITY
# DATE
# DIST
# VERSION

sub _md2pod {
    require Markdown::To::POD;

    my ($self, $md) = @_;
    my $pod = Markdown::To::POD::markdown_to_pod($md);
    # make sure we add a couple of blank lines in the end
    $pod =~ s/\s+\z//s;
    $pod . "\n\n\n";
}

sub _process_plugin_module {
    no strict 'refs';

    my ($self, $document, $input, $package) = @_;

    my $filename = $input->{filename};

    # XXX handle dynamically generated module (if there is such thing in the
    # future)
    local @INC = ("lib", @INC);

    {
        my $package_pm = $package;
        $package_pm =~ s!::!/!g;
        $package_pm .= ".pm";
        require $package_pm;
    }

    my $meta = $package->meta;

    (my $plugin_name = $package) =~ s/\APerinci::CmdLine::Plugin:://;

    # add Description section
    {
        my @pod;

        push @pod, $self->_md2pod($meta->{description})
            if $meta->{description};

        last unless @pod;

        $self->add_text_to_section(
            $document, join("", @pod), 'DESCRIPTION',
            {
                after_section => ['SYNOPSIS'],
                ignore => 1,
            });
    }

    $self->log(["Generated POD for '%s'", $filename]);
}

sub _process_pluginbundle_module {
    my ($self, $document, $input, $package) = @_;

    my $filename = $input->{filename};

    # XXX handle dynamically generated module (if there is such thing in the
    # future)
    local @INC = ("lib", @INC);

    # collect plugins list
    my %plugins;
    {
        require Module::List;
        my $res;
        {
            local @INC = ("lib");
            $res = Module::List::list_modules(
                "Perinci::CmdLine::Plugin::", {recurse=>1, list_modules=>1});
        }
        for my $mod (keys %$res) {
            my $plugin_name = $mod; $plugin_name =~ s/^Perinci::CmdLine::Plugin:://;
            local @INC = ("lib", @INC);
            my $mod_pm = $mod; $mod_pm =~ s!::!/!g; $mod_pm .= ".pm";
            require $mod_pm;
            $plugins{$plugin_name} = $mod->meta;
        }
    }

    # add POD section: PERINCI::CMDLINE PLUGINS
    {
        last unless keys %acs;
        require Markdown::To::POD;
        my @pod;
        push @pod, "The following Perinci::CmdLine::Plugin::* modules are included in this distribution:\n\n";

        push @pod, "=over\n\n";
        for my $plugin_name (sort keys %plugins) {
            my $meta = $plugins{$plugin_name};
            push @pod, "=item * L<$name|Perinci::CmdLine::Plugin::$plugin_name>\n\n";
            if (defined $meta->{summary}) {
                require String::PodQuote;
                push @pod, String::PodQuote::pod_quote($meta->{summary}), ".\n\n";
            }
            if ($meta->{description}) {
                my $pod = Markdown::To::POD::markdown_to_pod(
                    $meta->{description});
                push @pod, $pod, "\n\n";
            }
        }
        push @pod, "=back\n\n";
        $self->add_text_to_section(
            $document, join("", @pod), 'PERINCI::CMDLINE::PLUGIN MODULES',
            {after_section => ['DESCRIPTION']},
        );
    }

    # add POD section: SEE ALSO
    {
        # XXX don't add if current See Also already mentions it
        my @pod = (
            "L<Perinci::CmdLine>\n\n",
        );
        $self->add_text_to_section(
            $document, join('', @pod), 'SEE ALSO',
            {after_section => ['DESCRIPTION']},
        );
    }

    $self->log(["Generated POD for '%s'", $filename]);
}

sub weave_section {
    my ($self, $document, $input) = @_;

    my $filename = $input->{filename};

    return unless $filename =~ m!^lib/(.+)\.pm$!;
    my $package = $1;
    $package =~ s!/!::!g;
    if ($package =~ /\APerinci::CmdLine::Plugin::/) {
        $self->_process_plugin_module($document, $input, $package);
    } elsif ($package =~ /\APerinci::CmdLine::PluginBundle::/) {
        $self->_process_pluginbundle_module($document, $input, $package);
    }
}

1;
# ABSTRACT: Plugin to use when building Perinci::CmdLine::* distribution

=for Pod::Coverage weave_section

=head1 SYNOPSIS

In your F<weaver.ini>:

 [-Perinci::CmdLine]


=head1 DESCRIPTION

This plugin is used when building C<Perinci::CmdLine::*> distributions. It
currently does the following:

For F<Perinci/CmdLine/Plugin/*.pm> files:

=over

=item * Fill Description POD section from the meta's description

=back

For F<Perinci/CmdLine/PluginBundle/*.pm> files:

=over

=item * Add "Perinci::CmdLine::Plugin Modules" POD section listing Perinci::CmdLine::Plugin::* modules included in the distribution

=item * Add See Also POD section mentioning Perinci::CmdLine and some other related modules

=back


=head1 CONFIGURATION


=head1 SEE ALSO

L<Perinci::CmdLine>

L<Dist::Zilla::Plugin::Perinci::CmdLine>
